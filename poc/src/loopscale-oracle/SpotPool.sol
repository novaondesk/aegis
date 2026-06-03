// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
}

/// A thin constant-product pool (collateral token / USDC). Its instantaneous spot price
/// is trivially movable within a single transaction — exactly the property a lending
/// market must not depend on. Models the RateX PT pool Loopscale read from.
contract SpotPool {
    IERC20 public immutable base; // collateral token
    IERC20 public immutable quote; // USDC
    uint256 public reserveBase;
    uint256 public reserveQuote;

    constructor(IERC20 _base, IERC20 _quote, uint256 _reserveBase, uint256 _reserveQuote) {
        base = _base;
        quote = _quote;
        reserveBase = _reserveBase;
        reserveQuote = _reserveQuote;
    }

    /// Instantaneous spot price of base in USDC, 1e18-scaled.
    function spotPrice() external view returns (uint256) {
        return (reserveQuote * 1e18) / reserveBase;
    }

    /// Buy base with `quoteIn` USDC (x*y=k). Pushes the spot price UP — the manipulation.
    function buyBase(uint256 quoteIn) external returns (uint256 baseOut) {
        quote.transferFrom(msg.sender, address(this), quoteIn);
        uint256 k = reserveBase * reserveQuote;
        uint256 newQuote = reserveQuote + quoteIn;
        uint256 newBase = k / newQuote;
        baseOut = reserveBase - newBase;
        reserveBase = newBase;
        reserveQuote = newQuote;
        base.transfer(msg.sender, baseOut);
    }
}
