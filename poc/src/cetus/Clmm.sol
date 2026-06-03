// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LiquidityMath} from "./LiquidityMath.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
}

/// Minimal CLMM that mints a liquidity position. The deposit required for a given
/// `liquidity` is computed via `checked_shlw` (round-trip `<< 64` then `>> 64`, which is
/// identity when the guard holds). With the buggy guard, a crafted liquidity makes the
/// shift truncate, collapsing the required deposit to ~nothing for a gigantic position.
///
/// See docs/exploits/cetus-amm-overflow-2025-05-22.md
abstract contract ClmmBase {
    IERC20 public immutable token;
    mapping(address => uint256) public liquidityOf;

    constructor(IERC20 _token) {
        token = _token;
    }

    /// Deposit cost for `liquidity`: ((liquidity << 64) >> 64). Equals `liquidity` while
    /// the overflow guard holds; the variants differ only in that guard.
    function _depositCost(uint256 liquidity) internal pure virtual returns (uint256);

    function openPosition(uint256 liquidity) external returns (uint256 cost) {
        cost = _depositCost(liquidity);
        if (cost > 0) token.transferFrom(msg.sender, address(this), cost);
        liquidityOf[msg.sender] += liquidity;
    }

    /// Redeem a position for reserves, proportional to liquidity but capped at what the
    /// pool holds — a vastly oversized position simply drains the pool.
    function redeem() external returns (uint256 payout) {
        uint256 liq = liquidityOf[msg.sender];
        liquidityOf[msg.sender] = 0;
        uint256 bal = token.balanceOf(address(this));
        payout = liq < bal ? liq : bal;
        token.transfer(msg.sender, payout);
    }
}

contract VulnerableClmm is ClmmBase {
    constructor(IERC20 _token) ClmmBase(_token) {}

    function _depositCost(uint256 liquidity) internal pure override returns (uint256) {
        return LiquidityMath.shlw64Vulnerable(liquidity) >> 64; // truncates for 2^192
    }
}

contract SafeClmm is ClmmBase {
    constructor(IERC20 _token) ClmmBase(_token) {}

    function _depositCost(uint256 liquidity) internal pure override returns (uint256) {
        return LiquidityMath.shlw64Safe(liquidity) >> 64; // reverts before truncating
    }
}
