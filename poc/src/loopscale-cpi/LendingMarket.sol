// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
}

/// The PT (principal-token) rate source. On Solana this was a CPI into a program whose
/// id came from passed-in accounts; here it is an external call to a `rateProvider`
/// address supplied by the borrower. The EVM analog of "unvalidated CPI target" is an
/// "arbitrary external-call target".
interface IRateProvider {
    function getRate() external view returns (uint256); // 1e18-scaled PT/USD
}

/// Minimal model of Loopscale's loan-health check. It values PT collateral by reading a
/// rate from a rate provider, then lends against it.
///
/// See docs/exploits/loopscale-ratex-pricing-2025-04-26.md
abstract contract LendingMarketBase {
    IERC20 public immutable debtToken; // what borrowers withdraw (USDC)
    IERC20 public immutable collateralToken; // PT
    uint256 public constant LTV_BPS = 9000; // 90% loan-to-value

    mapping(address => uint256) public debt;

    constructor(IERC20 _debtToken, IERC20 _collateralToken) {
        debtToken = _debtToken;
        collateralToken = _collateralToken;
    }

    function _rate(IRateProvider provider) internal view virtual returns (uint256);

    /// Deposit PT collateral and borrow against its rate-derived value.
    function borrow(uint256 collateralAmount, IRateProvider provider) external {
        collateralToken.transferFrom(msg.sender, address(this), collateralAmount);
        uint256 rate = _rate(provider);
        uint256 collateralValue = (collateralAmount * rate) / 1e18;
        uint256 maxBorrow = (collateralValue * LTV_BPS) / 10000;
        debt[msg.sender] += maxBorrow;
        debtToken.transfer(msg.sender, maxBorrow);
    }
}

/// VULNERABLE: reads the rate from whatever `provider` the borrower passes — the CPI
/// target is never validated against the real RateX program id.
contract VulnerableLendingMarket is LendingMarketBase {
    constructor(IERC20 _debtToken, IERC20 _collateralToken)
        LendingMarketBase(_debtToken, _collateralToken)
    {}

    function _rate(IRateProvider provider) internal view override returns (uint256) {
        return provider.getRate(); // attacker-controlled program -> inflated PT price
    }
}

/// SAFE: the rate provider is pinned to a known, trusted address at construction; a
/// borrower-supplied provider is rejected (the Anchor `address = RATEX_PROGRAM` anchor).
contract SafeLendingMarket is LendingMarketBase {
    IRateProvider public immutable trustedProvider;

    constructor(IERC20 _debtToken, IERC20 _collateralToken, IRateProvider _trusted)
        LendingMarketBase(_debtToken, _collateralToken)
    {
        trustedProvider = _trusted;
    }

    function _rate(IRateProvider provider) internal view override returns (uint256) {
        require(provider == trustedProvider, "untrusted rate provider");
        return provider.getRate();
    }
}
