// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SpotPool} from "./SpotPool.sol";

/// Minimal lending market that values collateral and lends against it. The only
/// difference between the variants is the price ORACLE: a live pool spot price (movable
/// in one tx) vs a manipulation-resistant reference price.
///
/// See docs/exploits/loopscale-oracle-2025-04.md
abstract contract CollateralMarketBase {
    IERC20 public immutable collateralToken;
    IERC20 public immutable debtToken;
    uint256 public constant LTV_BPS = 9000;

    mapping(address => uint256) public debt;

    constructor(IERC20 _collateralToken, IERC20 _debtToken) {
        collateralToken = _collateralToken;
        debtToken = _debtToken;
    }

    function _price() internal view virtual returns (uint256);

    function borrow(uint256 collateralAmount) external {
        collateralToken.transferFrom(msg.sender, address(this), collateralAmount);
        uint256 value = (collateralAmount * _price()) / 1e18;
        uint256 maxBorrow = (value * LTV_BPS) / 10000;
        debt[msg.sender] += maxBorrow;
        debtToken.transfer(msg.sender, maxBorrow);
    }
}

/// VULNERABLE: prices collateral from a single pool's instantaneous spot price — no
/// TWAP, no staleness/deviation bound, no flash-loan awareness. A skewed pool prices
/// collateral arbitrarily high within the borrow transaction.
contract VulnerableCollateralMarket is CollateralMarketBase {
    SpotPool public immutable pool;

    constructor(IERC20 _collateralToken, IERC20 _debtToken, SpotPool _pool)
        CollateralMarketBase(_collateralToken, _debtToken)
    {
        pool = _pool;
    }

    function _price() internal view override returns (uint256) {
        return pool.spotPrice(); // movable in one tx — the bug
    }
}

/// SAFE: uses a manipulation-resistant reference price (a TWAP / multi-oracle median
/// settled before the transaction). A single-tx pool skew cannot move it, so borrowing
/// power stays bounded by the asset's real value.
contract SafeCollateralMarket is CollateralMarketBase {
    uint256 public immutable referencePrice; // set by a TWAP/aggregator, not the live pool

    constructor(IERC20 _collateralToken, IERC20 _debtToken, uint256 _referencePrice)
        CollateralMarketBase(_collateralToken, _debtToken)
    {
        referencePrice = _referencePrice;
    }

    function _price() internal view override returns (uint256) {
        return referencePrice; // immune to in-tx manipulation
    }
}
