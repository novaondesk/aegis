// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPricedPool {
    function pricePerShare() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
}

/// @title LendingMarket — accepts pool LP shares as collateral and lends ETH, pricing
/// the collateral via the pool's `pricePerShare()`. The victim/consumer in the PoC.
/// Not itself buggy — it just trusts a pool oracle that has read-only reentrancy.
contract LendingMarket {
    IPricedPool public immutable pool;
    mapping(address => uint256) public collateralShares;
    mapping(address => uint256) public debt;

    constructor(IPricedPool _pool) {
        pool = _pool;
    }

    function fund() external payable {} // LPs of the market deposit borrowable ETH

    function depositCollateral(uint256 shares) external {
        // PoC simplification: the market is told how many shares are pledged; a real
        // market would pull a collateral token. The point is the PRICING, below.
        collateralShares[msg.sender] += shares;
    }

    function maxBorrow(address user) public view returns (uint256) {
        uint256 collValue = (collateralShares[user] * pool.pricePerShare()) / 1e18;
        uint256 d = debt[user];
        return collValue > d ? collValue - d : 0;
    }

    function borrow(uint256 amount) external {
        require(amount <= maxBorrow(msg.sender), "UNDERCOLLATERALIZED");
        debt[msg.sender] += amount;
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "SEND");
    }
}
