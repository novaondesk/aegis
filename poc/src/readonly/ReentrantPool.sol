// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ReentrantPool — minimal LP pool with a READ-ONLY REENTRANCY bug.
/// INTENTIONALLY VULNERABLE — PoC only. Models the Curve `get_virtual_price` class.
///
/// THE BUG (checklist SC08 read-only reentrancy):
///   `removeLiquidity` updates `totalShares` BEFORE sending ETH, but updates the
///   internal `reserve` AFTER the external call. During the ETH callback the pool is
///   in an inconsistent state — supply already reduced, reserve still stale-high — so
///   the *view* function `pricePerShare()` returns an INFLATED price. Any consumer
///   that reads it as an oracle mid-callback is manipulated, even though no state-
///   changing function was re-entered.
contract ReentrantPool {
    uint256 public totalShares;
    uint256 public reserve; // internal ETH accounting (separate from address(this).balance)
    mapping(address => uint256) public balanceOf;

    function addLiquidity() external payable returns (uint256 shares) {
        shares = totalShares == 0 ? msg.value : (msg.value * totalShares) / reserve;
        reserve += msg.value;
        totalShares += shares;
        balanceOf[msg.sender] += shares;
    }

    /// price of 1e18 shares, in wei. Read by consumers as an oracle.
    function pricePerShare() external view returns (uint256) {
        if (totalShares == 0) return 1e18;
        return (reserve * 1e18) / totalShares;
    }

    function removeLiquidity(uint256 shares) external returns (uint256 ethOut) {
        ethOut = (reserve * shares) / totalShares;
        totalShares -= shares; //            (A) supply updated first
        balanceOf[msg.sender] -= shares;
        (bool ok,) = msg.sender.call{value: ethOut}(""); // (B) REENTRANCY: reserve still stale
        require(ok, "ETH_SEND");
        reserve -= ethOut; //                (C) reserve updated only now
    }

    receive() external payable {}
}
