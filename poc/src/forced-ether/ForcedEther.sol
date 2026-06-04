// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// Forced-ether balance assumption (SC02 logic).
///
/// A contract that treats `address(this).balance` as if it can only change through its own payable
/// entrypoints is wrong: `selfdestruct(target)` (and block/coinbase payouts, or pre-deployment
/// funding of a counterfactual address) can push ETH in unconditionally. Any logic that compares
/// the raw balance with strict equality — or unlocks behavior when the balance crosses a threshold
/// — can be bricked or triggered early by a forced transfer. (Ethernaut "Force"/"King" class.)
///
/// Fix: never derive control flow from `address(this).balance`. Track funds in an internal
/// accounting variable updated only by your own entrypoints, and use that.
///
/// See docs/exploits/forced-ether-balance-assumption.md

/// VULNERABLE: a crowdfund that finalizes only when raw balance EXACTLY equals tracked deposits.
contract VulnerableCrowdfund {
    uint256 public totalDeposited;
    bool public finalized;

    function deposit() external payable {
        totalDeposited += msg.value;
    }

    /// BUG: a single forced wei makes `address(this).balance != totalDeposited` forever, so this
    /// can never be called again — funds are permanently locked (griefing DoS).
    function finalize() external {
        require(address(this).balance == totalDeposited, "balance mismatch");
        finalized = true;
    }
}

/// SAFE: relies only on internal accounting; forced ether is simply ignored (and sweepable).
contract SafeCrowdfund {
    uint256 public totalDeposited;
    bool public finalized;

    function deposit() external payable {
        totalDeposited += msg.value;
    }

    function finalize() external {
        // Use internal accounting, not the raw balance. Surplus (forced) ether is irrelevant.
        require(address(this).balance >= totalDeposited, "underfunded");
        finalized = true;
    }
}

/// Pushes its balance into `target` via selfdestruct — works even against contracts with no
/// payable function and no `receive`.
contract ForceSender {
    constructor(address target) payable {
        selfdestruct(payable(target));
    }
}
