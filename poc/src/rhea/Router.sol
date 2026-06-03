// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, IRouter, SwapAction} from "./SwapRoute.sol";

/// Stand-in for Ref Finance. The attacker fabricated 123 fake tokens and 25 fake pools
/// so a route bouncing through them returns almost nothing in real terms, regardless of
/// the per-hop `minAmountOut` values the caller declares. We model that directly: the
/// route delivers a fixed, tiny `realOut` of the output token no matter how inflated
/// the declared minimums are.
contract Router is IRouter {
    IERC20 public immutable tokenIn;
    IERC20 public immutable tokenOut;
    uint256 public realOut; // what the fabricated pools actually pay out

    constructor(IERC20 _tokenIn, IERC20 _tokenOut) {
        tokenIn = _tokenIn;
        tokenOut = _tokenOut;
    }

    function setRealOut(uint256 v) external {
        realOut = v;
    }

    function executeRoute(uint256 amountIn, SwapAction[] calldata) external returns (uint256) {
        tokenIn.transferFrom(msg.sender, address(this), amountIn);
        tokenOut.transfer(msg.sender, realOut); // the route's true terminal output
        return realOut;
    }
}
