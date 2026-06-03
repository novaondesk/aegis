// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, IRouter, SwapAction} from "./SwapRoute.sol";

/// Minimal model of Burrowland's margin engine. A trader opens a position by swapping
/// `amountIn` of collateral through a multi-hop route; the engine validates the swap's
/// minimum output, then credits the trader collateral (denominated in the output token)
/// they can later withdraw against. The engine holds a real reserve of the output token.
///
/// The vulnerable/safe split is entirely in (a) how `getTokenOut` measures the route's
/// minimum and (b) whether the engine validates ACTUAL output before crediting.
///
/// See docs/exploits/rhea-finance-slippage-2026-04-16.md
abstract contract MarginEngineBase {
    IERC20 public immutable collateralToken; // tokenIn (e.g. ZEC)
    IERC20 public immutable outToken; // USDC reserve / what positions are credited in
    IRouter public immutable router;

    mapping(address => uint256) public collateral;

    constructor(IERC20 _collateralToken, IERC20 _outToken, IRouter _router) {
        collateralToken = _collateralToken;
        outToken = _outToken;
        router = _router;
    }

    /// The parser at the heart of the bug. Returns the validated minimum output the
    /// engine will trust for the whole route.
    function getTokenOut(SwapAction[] calldata route) public pure virtual returns (uint256);

    /// Hook: vulnerable credits the validated minimum, safe credits the actual output
    /// (and reverts if actual < validated).
    function _creditAmount(uint256 validatedMin, uint256 actualOut)
        internal
        pure
        virtual
        returns (uint256);

    function openTrade(uint256 amountIn, SwapAction[] calldata route) external {
        collateralToken.transferFrom(msg.sender, address(this), amountIn);
        collateralToken.approve(address(router), amountIn);

        uint256 validatedMin = getTokenOut(route);
        // is_min_amount_out_reasonable(): the Pyth check compares the (inflated) minimum
        // against oracle-priced endpoints. A higher minimum looks MORE over-collateralized,
        // so an inflated value sails through. Modelled as always-pass.

        uint256 actualOut = router.executeRoute(amountIn, route);
        require(actualOut > 0, "swap failed"); // the only rollback Burrowland had

        collateral[msg.sender] += _creditAmount(validatedMin, actualOut);
    }

    function withdraw(uint256 amount) external {
        require(amount <= collateral[msg.sender], "insufficient collateral");
        collateral[msg.sender] -= amount;
        outToken.transfer(msg.sender, amount);
    }
}

/// VULNERABLE: `getTokenOut` SUMS `minAmountOut` across every hop (intermediate hops
/// included), and the credited amount is that validated minimum — actual output is
/// never compared. A route that bounces through USDC N times inflates the minimum ~N×.
contract VulnerableMarginEngine is MarginEngineBase {
    constructor(IERC20 _collateralToken, IERC20 _outToken, IRouter _router)
        MarginEngineBase(_collateralToken, _outToken, _router)
    {}

    function getTokenOut(SwapAction[] calldata route) public pure override returns (uint256 sum) {
        for (uint256 i = 0; i < route.length; i++) {
            sum += route[i].minAmountOut; // BUG: sums intermediate hops too
        }
    }

    function _creditAmount(uint256 validatedMin, uint256 /*actualOut*/)
        internal
        pure
        override
        returns (uint256)
    {
        return validatedMin; // BUG: credits the inflated minimum, ignores what arrived
    }
}

/// SAFE: `getTokenOut` trusts only the TERMINAL hop's minimum, and the engine credits
/// the ACTUAL output after requiring it clear that minimum (post-swap validation).
contract SafeMarginEngine is MarginEngineBase {
    constructor(IERC20 _collateralToken, IERC20 _outToken, IRouter _router)
        MarginEngineBase(_collateralToken, _outToken, _router)
    {}

    function getTokenOut(SwapAction[] calldata route) public pure override returns (uint256) {
        if (route.length == 0) return 0;
        return route[route.length - 1].minAmountOut; // terminal output only
    }

    function _creditAmount(uint256 validatedMin, uint256 actualOut)
        internal
        pure
        override
        returns (uint256)
    {
        require(actualOut >= validatedMin, "slippage: output below minimum");
        return actualOut; // credit what actually arrived
    }
}
