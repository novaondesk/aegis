// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
}

/// Minimal model of a Balancer V2 scaled-balance stable pool (constant-sum in *upscaled*
/// space). Balances are upscaled by a per-token rate before the invariant math and the
/// resulting input is downscaled back to raw token units.
///
/// The bug is rounding-direction consistency: `_upscale` always rounds DOWN, and the
/// vulnerable `_swapGivenOut` also rounds the required INPUT down — favouring the trader
/// on both legs — so each swap leaks a sliver of the invariant `D`. 65 dust swaps in one
/// batch compounded that leak. The safe variant rounds the input UP (against the trader),
/// so `D` is non-decreasing.
///
/// See docs/exploits/balancer-v2-rounding-2025-11-03.md
abstract contract ScaledPoolBase {
    IERC20 public immutable token0;
    IERC20 public immutable token1;
    // Per-token scaling rates (1e18-scaled). A non-power-of-ten rate is what makes the
    // downscale division inexact, so the rounding direction actually matters.
    uint256 public immutable rate0; // e.g. 1.5e18
    uint256 public constant RATE1 = 1e18;

    uint256 public bal0; // raw token0 held
    uint256 public bal1; // raw token1 held

    constructor(IERC20 _token0, IERC20 _token1, uint256 _rate0, uint256 _bal0, uint256 _bal1) {
        token0 = _token0;
        token1 = _token1;
        rate0 = _rate0;
        bal0 = _bal0;
        bal1 = _bal1;
    }

    function _upscale(uint256 raw, uint256 rate) internal pure returns (uint256) {
        return (raw * rate) / 1e18; // mulDown — always rounds down
    }

    /// The pool invariant in upscaled space (constant-sum). Should never decrease from a
    /// swap; if it does, value has leaked to the trader.
    function invariantD() public view returns (uint256) {
        return _upscale(bal0, rate0) + _upscale(bal1, RATE1);
    }

    /// Downscale the required token0 input back to raw units — the one rounding decision
    /// that decides whether value leaks.
    function _downscaleInput(uint256 upscaledIn, uint256 rate) internal pure virtual returns (uint256);

    /// Trader buys `amountOut1` of token1 (constant-sum: upscaled-in == upscaled-out),
    /// paying token0.
    function swapGivenOut(uint256 amountOut1) external returns (uint256 amountIn0) {
        uint256 upOut = _upscale(amountOut1, RATE1); // requested output, rounded down
        uint256 upIn = upOut; // constant-sum 1:1 in upscaled space
        amountIn0 = _downscaleInput(upIn, rate0);

        if (amountIn0 > 0) token0.transferFrom(msg.sender, address(this), amountIn0);
        bal0 += amountIn0;
        bal1 -= amountOut1;
        token1.transfer(msg.sender, amountOut1);
    }
}

/// VULNERABLE: `_downscaleInput` rounds DOWN (divDown), so the trader is charged less
/// than the invariant requires. With a fractional rate the charge collapses to zero on
/// dust amounts — free token1, and `D` drops each swap.
contract VulnerableScaledPool is ScaledPoolBase {
    constructor(IERC20 _t0, IERC20 _t1, uint256 _rate0, uint256 _b0, uint256 _b1)
        ScaledPoolBase(_t0, _t1, _rate0, _b0, _b1)
    {}

    function _downscaleInput(uint256 upscaledIn, uint256 rate) internal pure override returns (uint256) {
        return (upscaledIn * 1e18) / rate; // divDown — favours the trader (the bug)
    }
}

/// SAFE: `_downscaleInput` rounds UP (divUp), always charging the trader at least the
/// invariant-required input, so `D` is non-decreasing.
contract SafeScaledPool is ScaledPoolBase {
    constructor(IERC20 _t0, IERC20 _t1, uint256 _rate0, uint256 _b0, uint256 _b1)
        ScaledPoolBase(_t0, _t1, _rate0, _b0, _b1)
    {}

    function _downscaleInput(uint256 upscaledIn, uint256 rate) internal pure override returns (uint256) {
        return (upscaledIn * 1e18 + (rate - 1)) / rate; // divUp — favours the pool (the fix)
    }
}
