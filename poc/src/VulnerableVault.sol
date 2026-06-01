// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

/// @title VulnerableVault — minimal ERC4626-style vault with the first-depositor /
/// share-inflation bug. INTENTIONALLY VULNERABLE — for PoC only.
///
/// THE BUG (checklist: Vault/ERC-4626 → SC07/SC02):
///  - Share price is derived from `asset.balanceOf(address(this))` (totalAssets),
///    so a *direct token transfer* (donation) to the vault changes price-per-share
///    without minting shares.
///  - There is no virtual-shares offset and no dead-shares mint on first deposit.
///  - `convertToShares` rounds DOWN.
/// Together these let the first depositor inflate PPS and make a later depositor's
/// shares round down, stealing the rounding remainder.
///
/// This is the mechanism class behind real share-accounting drains (Yearn-style
/// share-calc flaws, and the recurring ERC4626 inflation finding across audits).
contract VulnerableVault {
    IERC20 public immutable asset;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    constructor(IERC20 _asset) {
        asset = _asset;
    }

    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this)); // <-- donation-manipulable accounting
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply;
        if (supply == 0) return assets;
        return (assets * supply) / totalAssets(); // <-- rounds down, no offset
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply;
        if (supply == 0) return shares;
        return (shares * totalAssets()) / supply;
    }

    function deposit(uint256 assets) external returns (uint256 shares) {
        shares = convertToShares(assets); // computed on PRE-deposit totalAssets()
        require(shares != 0, "ZERO_SHARES"); // even with this guard, value can be stolen
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
