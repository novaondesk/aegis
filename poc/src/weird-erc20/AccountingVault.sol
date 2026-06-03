// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
}

/// "Weird ERC20" accounting: a vault assumes the amount it *requested* equals the amount it
/// *received*. With a fee-on-transfer (or rebasing/deflationary) token, less arrives than was
/// asked for, but the vault credits the full requested amount — so credited balances exceed the
/// tokens actually held, and the last withdrawers are left short. Fix: credit the measured
/// balance delta, not the parameter.
///
/// See docs/exploits/weird-erc20-accounting.md

/// VULNERABLE: credits the requested `amount`, ignoring transfer fees.
contract VulnerableVault {
    IERC20 public immutable token;
    mapping(address => uint256) public credited;

    constructor(IERC20 _token) {
        token = _token;
    }

    function deposit(uint256 amount) external {
        token.transferFrom(msg.sender, address(this), amount);
        credited[msg.sender] += amount; // BUG: assumes received == amount
    }

    function withdraw(uint256 amount) external {
        credited[msg.sender] -= amount;
        token.transfer(msg.sender, amount);
    }
}

/// SAFE: credits the actual balance delta produced by the transfer.
contract SafeVault {
    IERC20 public immutable token;
    mapping(address => uint256) public credited;

    constructor(IERC20 _token) {
        token = _token;
    }

    function deposit(uint256 amount) external returns (uint256 received) {
        uint256 balBefore = token.balanceOf(address(this));
        token.transferFrom(msg.sender, address(this), amount);
        received = token.balanceOf(address(this)) - balBefore; // measure what actually arrived
        credited[msg.sender] += received;
    }

    function withdraw(uint256 amount) external {
        credited[msg.sender] -= amount;
        token.transfer(msg.sender, amount);
    }
}
