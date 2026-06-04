// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
}

/// MasterChef-style reward accounting bug: `pending = amount * accRewardPerShare - rewardDebt`.
/// After paying `pending`, the contract must advance `rewardDebt` to the new checkpoint. If it
/// forgets, `pending` stays the same and the staker re-harvests the same reward indefinitely,
/// draining the reward pool. (The stake-token transfer is abstracted away to keep the focus on
/// the debt math.) Fix: update rewardDebt on every harvest/deposit/withdraw.
///
/// See docs/exploits/incorrect-reward-accounting.md

abstract contract ChefBase {
    IERC20 public immutable reward;
    uint256 public accRewardPerShare; // scaled by 1e12

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    mapping(address => UserInfo) public users;

    constructor(IERC20 r) {
        reward = r;
    }

    /// Stand-in for updatePool(): in a real chef, accRewardPerShare grows over time as rewards
    /// accrue to the pool. Here a test bumps it directly.
    function accrue(uint256 perShareIncrease) external {
        accRewardPerShare += perShareIncrease;
    }

    function deposit(uint256 amount) external {
        UserInfo storage u = users[msg.sender];
        u.amount += amount;
        u.rewardDebt = (u.amount * accRewardPerShare) / 1e12; // checkpoint at deposit
    }

    function pending(address who) public view returns (uint256) {
        UserInfo storage u = users[who];
        return (u.amount * accRewardPerShare) / 1e12 - u.rewardDebt;
    }

    function harvest() external virtual;
}

/// VULNERABLE: pays pending but never advances rewardDebt.
contract VulnerableChef is ChefBase {
    constructor(IERC20 r) ChefBase(r) {}

    function harvest() external override {
        UserInfo storage u = users[msg.sender];
        uint256 p = (u.amount * accRewardPerShare) / 1e12 - u.rewardDebt;
        // BUG: rewardDebt not updated -> pending stays the same -> re-harvestable
        reward.transfer(msg.sender, p);
    }
}

/// SAFE: advances rewardDebt to the current checkpoint after paying.
contract SafeChef is ChefBase {
    constructor(IERC20 r) ChefBase(r) {}

    function harvest() external override {
        UserInfo storage u = users[msg.sender];
        uint256 p = (u.amount * accRewardPerShare) / 1e12 - u.rewardDebt;
        u.rewardDebt = (u.amount * accRewardPerShare) / 1e12; // checkpoint BEFORE paying out
        reward.transfer(msg.sender, p);
    }
}
