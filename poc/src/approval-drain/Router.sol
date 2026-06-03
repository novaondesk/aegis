// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// Minimal swap router/aggregator. Users grant it ERC20 approvals so it can pull their
/// tokens during a swap, and it forwards a call to a target "adapter". The bug: it
/// forwards an ARBITRARY (target, data) while holding everyone's approvals — so an
/// attacker points it at the token itself with `transferFrom(victim, attacker, …)`.
/// This is the Seneca / Socket / Sushi-RouteProcessor2 "arbitrary external call drains
/// approvals" class.
///
/// See docs/exploits/approval-drain-arbitrary-call-2024-02.md
abstract contract RouterBase {
    /// Execute a swap step by calling `target` with `data`. (In a real router this is how
    /// a DEX adapter gets invoked.)
    function execute(address target, bytes calldata data) external returns (bytes memory) {
        _check(target);
        (bool ok, bytes memory ret) = target.call(data);
        require(ok, "call failed");
        return ret;
    }

    function _check(address target) internal view virtual;
}

/// VULNERABLE: no restriction on `target`. The router's standing approvals let the call
/// move anyone's tokens.
contract VulnerableRouter is RouterBase {
    function _check(address) internal view override {} // anything goes — the bug
}

/// SAFE: `target` must be an allow-listed adapter set by governance; token contracts (and
/// any unknown address) are rejected, so a crafted transferFrom can never be forwarded.
contract SafeRouter is RouterBase {
    mapping(address => bool) public allowedAdapter;

    constructor(address[] memory adapters) {
        for (uint256 i = 0; i < adapters.length; i++) allowedAdapter[adapters[i]] = true;
    }

    function _check(address target) internal view override {
        require(allowedAdapter[target], "target not allow-listed");
    }
}
