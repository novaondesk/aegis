// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Privacy} from "../src/levels/Privacy.sol";

/// Ethernaut #12 "Privacy" → information exposure (no catalog entry; `private` isn't secret). The key
/// is `bytes16(data[2])`, and `data[2]` lives in storage slot 5 (slot0 locked, 1 ID, 2 packed
/// uint8/8/16, 3-5 the bytes32[3]). Win: !locked.
contract PrivacyTest is Test {
    function test_solve_privacy() public {
        bytes32[3] memory data =
            [keccak256("a"), keccak256("b"), keccak256("the real key lives here")];
        Privacy lvl = new Privacy(data);

        bytes32 slot5 = vm.load(address(lvl), bytes32(uint256(5))); // data[2]
        lvl.unlock(bytes16(slot5));

        assertEq(lvl.locked(), false, "unlocked with the leaked storage slot");
    }
}
