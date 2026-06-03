// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// Classic checks-effects-interactions (CEI) reentrancy — the state-changing sibling of
/// `read-only-reentrancy`. `withdraw` sends ETH via a low-level call BEFORE zeroing the caller's
/// balance, so a malicious `receive()` re-enters `withdraw` while the balance still reads full and
/// drains the contract. Behind The DAO (2016) and many lending/vault drains. Fix: update state
/// before the external call (CEI) and/or a reentrancy lock.
///
/// See docs/exploits/cei-reentrancy.md
abstract contract BankBase {
    mapping(address => uint256) public balanceOf;

    function deposit() external payable {
        balanceOf[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external virtual;

    receive() external payable {}
}

/// VULNERABLE: interaction (ETH send) happens before the effect (balance decrement).
contract VulnerableBank is BankBase {
    function withdraw(uint256 amount) external override {
        require(balanceOf[msg.sender] >= amount, "insufficient");
        (bool ok,) = msg.sender.call{value: amount}(""); // INTERACTION first
        require(ok, "send failed");
        // BUG: EFFECT after the call -> re-entrant while balance still reads full. `unchecked`
        // mirrors the pre-0.8 arithmetic of the real-world contracts in this class (the repeated
        // decrement on unwind wraps instead of reverting).
        unchecked {
            balanceOf[msg.sender] -= amount;
        }
    }
}

/// SAFE: effect before interaction (CEI) + a reentrancy lock.
contract SafeBank is BankBase {
    uint256 private _locked = 1;

    modifier nonReentrant() {
        require(_locked == 1, "reentrant");
        _locked = 2;
        _;
        _locked = 1;
    }

    function withdraw(uint256 amount) external override nonReentrant {
        require(balanceOf[msg.sender] >= amount, "insufficient");
        balanceOf[msg.sender] -= amount; // EFFECT first
        (bool ok,) = msg.sender.call{value: amount}(""); // INTERACTION last
        require(ok, "send failed");
    }
}
