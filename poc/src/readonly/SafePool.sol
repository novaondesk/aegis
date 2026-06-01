// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title SafePool — ReentrantPool with the read-only-reentrancy fix.
/// FIX: Checks-Effects-Interactions — update `reserve` BEFORE the external call, so
/// `pricePerShare()` is always consistent, even inside a callback. (Curve's later fix
/// was an explicit reentrancy lock that view functions also check; CEI achieves the
/// same here for this minimal model.)
contract SafePool {
    uint256 public totalShares;
    uint256 public reserve;
    mapping(address => uint256) public balanceOf;

    function addLiquidity() external payable returns (uint256 shares) {
        shares = totalShares == 0 ? msg.value : (msg.value * totalShares) / reserve;
        reserve += msg.value;
        totalShares += shares;
        balanceOf[msg.sender] += shares;
    }

    function pricePerShare() external view returns (uint256) {
        if (totalShares == 0) return 1e18;
        return (reserve * 1e18) / totalShares;
    }

    function removeLiquidity(uint256 shares) external returns (uint256 ethOut) {
        ethOut = (reserve * shares) / totalShares;
        totalShares -= shares;
        balanceOf[msg.sender] -= shares;
        reserve -= ethOut; // <-- effects BEFORE interaction: price stays consistent
        (bool ok,) = msg.sender.call{value: ethOut}("");
        require(ok, "ETH_SEND");
    }

    receive() external payable {}
}
