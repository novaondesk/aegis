// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// Missing access control on privileged functions — the single largest exploit class by count in
/// DeFiHackLabs. Two faces here: (1) a public `mint` with no owner gate lets anyone print supply
/// (PAID Network-class, ~$180M nominal), and (2) an `initialize` with no once-guard lets anyone
/// (re)take ownership of a freshly deployed/uninitialized contract. Fix: onlyOwner + initializer.
///
/// See docs/exploits/unprotected-privileged-fn.md

/// VULNERABLE: initialize is re-callable and mint is ungated.
contract VulnerableToken {
    address public owner;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    function initialize(address o) external {
        owner = o; // BUG: no once-guard -> anyone re-initializes and takes ownership
    }

    function mint(address to, uint256 amount) external {
        // BUG: no access control -> anyone mints unlimited supply
        balanceOf[to] += amount;
        totalSupply += amount;
    }
}

/// SAFE: initialize runs once; mint is owner-only.
contract SafeToken {
    address public owner;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    bool private _initialized;

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    function initialize(address o) external {
        require(!_initialized, "already initialized");
        _initialized = true;
        owner = o;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        balanceOf[to] += amount;
        totalSupply += amount;
    }
}
