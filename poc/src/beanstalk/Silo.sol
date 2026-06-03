// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
}

/// Minimal model of Beanstalk's Silo: deposit an asset, receive "Roots" (governance
/// voting power) 1:1. Each deposit is stamped with the block time it was made, so the
/// difference between *real-time* and *snapshot* voting power can be measured — that
/// gap is exactly what the 2022-04-17 flash-loan attack exploited.
///
/// See docs/exploits/beanstalk-governance-flashloan-2022-04-17.md
contract Silo {
    IERC20 public immutable asset;

    struct Deposit {
        uint256 roots;
        uint256 time;
    }

    mapping(address => Deposit[]) public deposits;
    mapping(address => uint256) public rootsOf; // real-time roots ("current storage read")
    uint256 public totalRoots;

    constructor(IERC20 _asset) {
        asset = _asset;
    }

    function deposit(uint256 amount) external returns (uint256 roots) {
        asset.transferFrom(msg.sender, address(this), amount);
        roots = amount; // 1:1 for the model
        deposits[msg.sender].push(Deposit({roots: roots, time: block.timestamp}));
        rootsOf[msg.sender] += roots;
        totalRoots += roots;
    }

    /// Withdraw everything and burn the caller's roots (used to unwind a flash-loaned
    /// deposit in the same transaction).
    function withdrawAll() external returns (uint256 amount) {
        amount = rootsOf[msg.sender];
        delete deposits[msg.sender];
        totalRoots -= amount;
        rootsOf[msg.sender] = 0;
        asset.transfer(msg.sender, amount);
    }

    /// Snapshot voting power: roots held by `who` from deposits made at or before
    /// `asOf`. Deposits created after a proposal's snapshot do not count — this is the
    /// fix the vulnerable governance is missing.
    function rootsOfAt(address who, uint256 asOf) external view returns (uint256 total) {
        Deposit[] storage ds = deposits[who];
        for (uint256 i = 0; i < ds.length; i++) {
            if (ds[i].time <= asOf) total += ds[i].roots;
        }
    }
}
