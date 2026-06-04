// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {MagicNum} from "../src/levels/MagicNum.sol";

/// Ethernaut #18 "MagicNumber" → raw-bytecode technique (no catalog entry). The solver must be a
/// contract of <= 10 bytes runtime that returns 42 for any call. Win: solver returns 42 and its code
/// is <= 10 bytes.
contract MagicNumTest is Test {
    function test_solve_magicnum() public {
        MagicNum lvl = new MagicNum();

        // runtime (10 bytes): PUSH1 0x2a; PUSH1 0; MSTORE; PUSH1 0x20; PUSH1 0; RETURN
        // init: copy that runtime out
        bytes memory init = hex"600a600c600039600a6000f3602a60005260206000f3";
        address solver;
        assembly {
            solver := create(0, add(init, 0x20), mload(init))
        }
        require(solver != address(0), "deploy failed");
        lvl.setSolver(solver);

        (bool ok, bytes memory ret) = solver.staticcall("");
        require(ok, "solver call failed");
        assertEq(abi.decode(ret, (uint256)), 42, "solver returns 42");
        assertLe(solver.code.length, 10, "solver is <= 10 bytes");
    }
}
