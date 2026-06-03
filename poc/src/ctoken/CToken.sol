// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
}

/// Minimal Compound-style cToken. `exchangeRate = cash / totalSupply`, so an EMPTY (or
/// near-empty) market lets the first minter donate underlying directly to inflate the
/// rate, then a later depositor's round-down mint is siphoned — the empty-market /
/// exchange-rate-inflation bug behind Hundred Finance, Sonne, Onyx, etc.
///
/// See docs/exploits/ctoken-empty-market-exchange-rate-2023-04.md
abstract contract CTokenBase {
    IERC20 public immutable underlying;
    uint256 public totalSupply; // cTokens
    mapping(address => uint256) public balanceOf;
    uint256 internal constant INITIAL_RATE = 1e18;

    constructor(IERC20 _underlying) {
        underlying = _underlying;
    }

    function getCash() public view returns (uint256) {
        return underlying.balanceOf(address(this));
    }

    /// exchangeRate scaled by 1e18: how much underlying one cToken redeems for.
    function exchangeRate() public view returns (uint256) {
        if (totalSupply == 0) return INITIAL_RATE;
        return (getCash() * 1e18) / totalSupply;
    }

    function _mintAllowed(uint256 minted) internal virtual;

    function mint(uint256 underlyingAmount) external returns (uint256 minted) {
        uint256 rate = exchangeRate();
        underlying.transferFrom(msg.sender, address(this), underlyingAmount);
        minted = (underlyingAmount * 1e18) / rate; // round down — the bug surface
        _mintAllowed(minted);
        totalSupply += minted;
        balanceOf[msg.sender] += minted;
    }

    function redeem(uint256 cTokens) external returns (uint256 amount) {
        uint256 rate = exchangeRate();
        amount = (cTokens * rate) / 1e18;
        totalSupply -= cTokens;
        balanceOf[msg.sender] -= cTokens;
        underlying.transfer(msg.sender, amount);
    }
}

/// VULNERABLE: empty market, no dead-shares seed, no zero-mint guard. First minter holds
/// 1 cToken, donates underlying, inflates the rate, and a victim's deposit rounds to ~0.
contract VulnerableCToken is CTokenBase {
    constructor(IERC20 _u) CTokenBase(_u) {}

    function _mintAllowed(uint256) internal override {} // anything goes
}

/// SAFE: the market is seeded with burned "dead" cTokens at construction (so it's never
/// empty/tiny and price-per-share can't be cheaply moved), and a mint that would round to
/// zero cTokens reverts.
contract SafeCToken is CTokenBase {
    constructor(IERC20 _u, uint256 seedUnderlying) CTokenBase(_u) {
        // Deployer pre-funds this contract with `seedUnderlying`; mint dead shares to
        // address(1) so totalSupply/cash start large and locked.
        uint256 minted = (seedUnderlying * 1e18) / INITIAL_RATE;
        totalSupply += minted;
        balanceOf[address(1)] += minted; // burned — unredeemable
    }

    function _mintAllowed(uint256 minted) internal pure override {
        require(minted > 0, "zero cTokens minted"); // no free donation rounding
    }
}
