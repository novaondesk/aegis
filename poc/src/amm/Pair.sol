// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
}

/// AMM-pair first-deposit / share-skim manipulation (Uniswap-V2-fork variant of the inflation
/// attack). The first LP mints a tiny amount of LP, donates tokens directly to the pair to inflate
/// the value of one LP unit, and a later LP's `min(...)` round-down mints them ZERO LP — their
/// deposit is absorbed and the first LP (still 100% of supply) redeems the whole pool. Uniswap V2
/// blocks this by burning a permanent MINIMUM_LIQUIDITY on the first mint and rejecting zero-LP
/// mints. Fix: lock MINIMUM_LIQUIDITY + require(liquidity > 0).
///
/// See docs/exploits/first-deposit-amm-skim.md

abstract contract PairBase {
    IERC20 public immutable t0;
    IERC20 public immutable t1;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    constructor(IERC20 a, IERC20 b) {
        t0 = a;
        t1 = b;
    }

    function _mint(address to, uint256 v) internal {
        totalSupply += v;
        balanceOf[to] += v;
    }

    function _burn(address from, uint256 v) internal {
        totalSupply -= v;
        balanceOf[from] -= v;
    }

    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function addLiquidity(uint256 a0, uint256 a1) external returns (uint256 liquidity) {
        uint256 r0 = t0.balanceOf(address(this)); // reserves = current balance (donation-sensitive)
        uint256 r1 = t1.balanceOf(address(this));
        t0.transferFrom(msg.sender, address(this), a0);
        t1.transferFrom(msg.sender, address(this), a1);
        liquidity = _computeLiquidity(a0, a1, r0, r1);
        _mint(msg.sender, liquidity);
    }

    function removeLiquidity(uint256 liq) external returns (uint256 a0, uint256 a1) {
        uint256 r0 = t0.balanceOf(address(this));
        uint256 r1 = t1.balanceOf(address(this));
        a0 = (liq * r0) / totalSupply;
        a1 = (liq * r1) / totalSupply;
        _burn(msg.sender, liq);
        t0.transfer(msg.sender, a0);
        t1.transfer(msg.sender, a1);
    }

    function _computeLiquidity(uint256 a0, uint256 a1, uint256 r0, uint256 r1)
        internal
        virtual
        returns (uint256 liquidity);
}

/// VULNERABLE: no MINIMUM_LIQUIDITY lock, no zero-LP guard.
contract VulnerablePair is PairBase {
    constructor(IERC20 a, IERC20 b) PairBase(a, b) {}

    function _computeLiquidity(uint256 a0, uint256 a1, uint256 r0, uint256 r1)
        internal
        view
        override
        returns (uint256 liquidity)
    {
        if (totalSupply == 0) {
            liquidity = _sqrt(a0 * a1); // BUG: first minter can hold 100% of a tiny supply
        } else {
            liquidity = _min((a0 * totalSupply) / r0, (a1 * totalSupply) / r1); // BUG: can round to 0
        }
    }
}

/// SAFE: burns MINIMUM_LIQUIDITY on the first mint (so supply is never tiny and donations can't
/// cheaply move price-per-LP) and rejects zero-LP mints.
contract SafePair is PairBase {
    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    constructor(IERC20 a, IERC20 b) PairBase(a, b) {}

    function _computeLiquidity(uint256 a0, uint256 a1, uint256 r0, uint256 r1)
        internal
        override
        returns (uint256 liquidity)
    {
        if (totalSupply == 0) {
            liquidity = _sqrt(a0 * a1) - MINIMUM_LIQUIDITY; // reverts (underflow) on a dust first mint
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently locked
        } else {
            liquidity = _min((a0 * totalSupply) / r0, (a1 * totalSupply) / r1);
        }
        require(liquidity > 0, "insufficient liquidity minted");
    }
}
