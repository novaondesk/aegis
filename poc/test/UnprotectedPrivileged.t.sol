// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {VulnerableToken, SafeToken} from "../src/access/MintableToken.sol";

/// PoC for missing access control on privileged functions (PAID Network-class; the largest DHL
/// class by count).
///   forge test --match-contract UnprotectedPrivileged -vvv
///
/// Invariant (SC01): privileged state changes (mint, ownership) must be reachable only by an
/// authorized caller and one-shot initializers must not be re-callable.
///
/// See docs/exploits/unprotected-privileged-fn.md
contract UnprotectedPrivilegedTest is Test {
    address deployer = makeAddr("deployer");
    address attacker = makeAddr("attacker");

    function test_vulnerable_anyoneMintsAndTakesOwnership() public {
        vm.prank(deployer);
        VulnerableToken t = new VulnerableToken();
        vm.prank(deployer);
        t.initialize(deployer);

        // Anyone can mint unlimited supply.
        vm.prank(attacker);
        t.mint(attacker, 1_000_000e18);
        assertEq(t.balanceOf(attacker), 1_000_000e18, "ungated mint printed supply");

        // Anyone can re-initialize and seize ownership.
        vm.prank(attacker);
        t.initialize(attacker);
        assertEq(t.owner(), attacker, "ownership hijacked via re-init");
    }

    function test_safe_gatedMintAndOnceOnlyInit() public {
        vm.prank(deployer);
        SafeToken t = new SafeToken();
        vm.prank(deployer);
        t.initialize(deployer);

        // Re-initialization is rejected.
        vm.prank(attacker);
        vm.expectRevert(bytes("already initialized"));
        t.initialize(attacker);

        // Ungated mint is rejected.
        vm.prank(attacker);
        vm.expectRevert(bytes("not owner"));
        t.mint(attacker, 1_000_000e18);

        // Owner can still mint.
        vm.prank(deployer);
        t.mint(deployer, 100e18);
        assertEq(t.balanceOf(deployer), 100e18, "owner mint works");
        assertEq(t.owner(), deployer, "ownership intact");
    }
}
