// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
}

/// One hop of a multi-hop swap route. `minAmountOut` is the slippage floor for THAT
/// hop's output token — which, for every hop except the last, is immediately spent as
/// the input to the next hop. Only the terminal hop's `minAmountOut` is a real
/// guarantee to the user.
struct SwapAction {
    uint256 minAmountOut;
}

interface IRouter {
    /// Executes the route and returns the ACTUAL terminal output delivered to caller.
    function executeRoute(uint256 amountIn, SwapAction[] calldata route) external returns (uint256);
}
