// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "./VulnerableVault.sol";

/// @title SafeVault — same vault, with the OpenZeppelin-style virtual-shares
/// offset mitigation (ERC4626 since v4.9). Used to show the attack no longer pays.
///
/// FIX: a virtual offset of `10**_DECIMALS_OFFSET` is added to both supply and
/// assets in the conversion, so the first depositor cannot drive PPS to a point
/// where a later deposit rounds to ~0. The attacker would have to donate orders of
/// magnitude more than they can ever recover, making the attack unprofitable.
contract SafeVault {
    IERC20 public immutable asset;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    uint256 private constant OFFSET = 1e3; // 10**3 virtual shares

    constructor(IERC20 _asset) {
        asset = _asset;
    }

    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        // (assets * (supply + offset)) / (totalAssets + 1)
        return (assets * (totalSupply + OFFSET)) / (totalAssets() + 1);
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        return (shares * (totalAssets() + 1)) / (totalSupply + OFFSET);
    }

    function deposit(uint256 assets) external returns (uint256 shares) {
        shares = convertToShares(assets);
        require(shares != 0, "ZERO_SHARES");
        require(asset.transferFrom(msg.sender, address(this), assets), "XFER");
        totalSupply += shares;
        balanceOf[msg.sender] += shares;
    }

    function redeem(uint256 shares) external returns (uint256 assets) {
        assets = convertToAssets(shares);
        balanceOf[msg.sender] -= shares;
        totalSupply -= shares;
        require(asset.transfer(msg.sender, assets), "XFER");
    }
}
