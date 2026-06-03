// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
}

/// The thin, self-referential market the oracle aggregates — buying here moves the very
/// price used to value MNGO collateral. Models MNGO-PERP / MNGO spot on Mango.
contract ThinMarket {
    IERC20 public immutable token; // MNGO
    IERC20 public immutable quote; // USDC
    uint256 public reserveToken;
    uint256 public reserveQuote;

    constructor(IERC20 _token, IERC20 _quote, uint256 _reserveToken, uint256 _reserveQuote) {
        token = _token;
        quote = _quote;
        reserveToken = _reserveToken;
        reserveQuote = _reserveQuote;
    }

    function price() external view returns (uint256) {
        return (reserveQuote * 1e18) / reserveToken;
    }

    function buy(uint256 quoteIn) external returns (uint256 out) {
        quote.transferFrom(msg.sender, address(this), quoteIn);
        uint256 k = reserveToken * reserveQuote;
        uint256 newQuote = reserveQuote + quoteIn;
        uint256 newToken = k / newQuote;
        out = reserveToken - newToken;
        reserveToken = newToken;
        reserveQuote = newQuote;
        token.transfer(msg.sender, out);
    }
}

/// Minimal cross-margin lending market. A low-liquidity governance token (MNGO) is
/// accepted as collateral. The vulnerable/safe split is the COLLATERAL RISK DESIGN, not
/// the oracle source — both read the same manipulable market price.
///
/// See docs/exploits/mango-markets-oracle-manipulation.md
abstract contract CrossMarginBase {
    IERC20 public immutable collateral; // MNGO
    IERC20 public immutable debtToken; // USDC
    ThinMarket public immutable oracle;

    mapping(address => uint256) public debt;

    constructor(IERC20 _collateral, IERC20 _debtToken, ThinMarket _oracle) {
        collateral = _collateral;
        debtToken = _debtToken;
        oracle = _oracle;
    }

    function _maxBorrow(uint256 collateralAmount) internal view virtual returns (uint256);

    function borrow(uint256 collateralAmount) external {
        collateral.transferFrom(msg.sender, address(this), collateralAmount);
        uint256 maxBorrow = _maxBorrow(collateralAmount);
        debt[msg.sender] += maxBorrow;
        debtToken.transfer(msg.sender, maxBorrow);
    }
}

/// VULNERABLE: MNGO at 100% collateral weight, no per-asset borrow cap, no price-
/// deviation circuit breaker. A spiked oracle directly inflates borrowing power.
contract VulnerableCrossMargin is CrossMarginBase {
    constructor(IERC20 _collateral, IERC20 _debtToken, ThinMarket _oracle)
        CrossMarginBase(_collateral, _debtToken, _oracle)
    {}

    function _maxBorrow(uint256 collateralAmount) internal view override returns (uint256) {
        return (collateralAmount * oracle.price()) / 1e18; // 100% weight, uncapped
    }
}

/// SAFE: the collateral-design controls Mango lacked. (1) a price-deviation circuit
/// breaker rejects an oracle that has jumped far from a settled reference; (2) a per-
/// asset borrow cap bounds exposure to a thin token; (3) a sub-100% collateral weight.
contract SafeCrossMargin is CrossMarginBase {
    uint256 public immutable referencePrice; // settled reference (e.g. TWAP)
    uint256 public constant MAX_DEVIATION_BPS = 2000; // reject >20% jumps
    uint256 public constant COLLATERAL_WEIGHT_BPS = 6000; // 60% weight for a thin token
    uint256 public immutable borrowCap; // per-asset cap

    constructor(IERC20 _collateral, IERC20 _debtToken, ThinMarket _oracle, uint256 _ref, uint256 _cap)
        CrossMarginBase(_collateral, _debtToken, _oracle)
    {
        referencePrice = _ref;
        borrowCap = _cap;
    }

    function _maxBorrow(uint256 collateralAmount) internal view override returns (uint256) {
        uint256 p = oracle.price();
        // Circuit breaker: a manipulated spike is rejected outright.
        uint256 hi = referencePrice + (referencePrice * MAX_DEVIATION_BPS) / 10000;
        require(p <= hi, "oracle deviation: circuit breaker");
        uint256 value = (collateralAmount * p) / 1e18;
        uint256 weighted = (value * COLLATERAL_WEIGHT_BPS) / 10000;
        return weighted > borrowCap ? borrowCap : weighted; // per-asset cap
    }
}
