// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
}

/// Cross-chain bridge Merkle-proof verification flaw (Verus, ~$11.6M, 2026-05-17; same family as
/// Nomad 2022). The bridge verifies a withdrawal's Merkle proof against a root, but never checks
/// that the root is one actually committed by the authenticated source — it trusts a root supplied
/// alongside the proof. So an attacker builds their own tree containing a fraudulent withdrawal,
/// computes its root, and submits it: the proof checks out against the attacker's own root. Fix:
/// only accept proofs against roots committed by the authenticated relayer/light-client.
///
/// See docs/exploits/verus-bridge-merkle-2026-05-17.md

abstract contract MerkleBridgeBase {
    IERC20 public immutable token;
    address public immutable relayer; // the authenticated source of valid roots

    constructor(IERC20 t, address _relayer) {
        token = t;
        relayer = _relayer;
    }

    function _processProof(bytes32[] calldata proof, bytes32 leaf) internal pure returns (bytes32 h) {
        h = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            h = h <= proof[i]
                ? keccak256(abi.encodePacked(h, proof[i]))
                : keccak256(abi.encodePacked(proof[i], h));
        }
    }

    function withdraw(address to, uint256 amount, bytes32[] calldata proof, bytes32 root)
        external
        virtual;
}

/// VULNERABLE: verifies against a caller-supplied `root` that is never constrained to an
/// authenticated/committed root.
contract VulnerableMerkleBridge is MerkleBridgeBase {
    constructor(IERC20 t, address r) MerkleBridgeBase(t, r) {}

    function withdraw(address to, uint256 amount, bytes32[] calldata proof, bytes32 root)
        external
        override
    {
        bytes32 leaf = keccak256(abi.encodePacked(to, amount));
        require(_processProof(proof, leaf) == root, "bad proof"); // BUG: `root` is unverified
        token.transfer(to, amount);
    }
}

/// SAFE: the root must be one the authenticated relayer has committed.
contract SafeMerkleBridge is MerkleBridgeBase {
    mapping(bytes32 => bool) public committedRoots;
    mapping(bytes32 => bool) public spent;

    constructor(IERC20 t, address r) MerkleBridgeBase(t, r) {}

    /// Only the authenticated source can publish a root (in reality a light-client/threshold proof).
    function commitRoot(bytes32 root) external {
        require(msg.sender == relayer, "not relayer");
        committedRoots[root] = true;
    }

    function withdraw(address to, uint256 amount, bytes32[] calldata proof, bytes32 root)
        external
        override
    {
        require(committedRoots[root], "unknown root"); // the fix: authenticated root only
        bytes32 leaf = keccak256(abi.encodePacked(to, amount));
        require(!spent[leaf], "already withdrawn");
        require(_processProof(proof, leaf) == root, "bad proof");
        spent[leaf] = true;
        token.transfer(to, amount);
    }
}
