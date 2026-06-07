// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// TAC Bridge — Jetton Wallet Code-Hash Verification Bypass ($2.85M, 2026-05-11).
///
/// The TAC sequencer authenticated inbound bridge messages by checking the sender
/// jetton wallet's CODE HASH against the canonical jetton-wallet code, but never
/// verified that the wallet's storage pointed to the EXPECTED minter (jetton master)
/// for the claimed asset. An attacker deployed a wallet with the canonical code hash
/// but bound to an attacker-controlled minter, minted ~302M fake BLUM, and bridged it out.
///
/// EVM model of the same bug: the minter is held in STORAGE (not an immutable), so every
/// JettonWallet instance has byte-identical runtime code -> the SAME `codehash`, regardless
/// of which minter it points to. Code-hash checks therefore cannot distinguish a genuine
/// wallet from an impersonator. The fix is to verify minter/master PROVENANCE, not structure.
///
/// See docs/exploits/tac-bridge-jetton-impersonation-2026-05-11.md

/// Minimal jetton-wallet analog. `minter` lives in STORAGE, so all instances share one
/// runtime bytecode (and thus one codehash) while pointing to different minters.
contract JettonWallet {
    address public minter; // the jetton master this wallet belongs to

    constructor(address _minter) {
        minter = _minter;
    }
}

/// VULNERABLE: authenticates the sender wallet by code hash ONLY (structural check).
/// Any contract sharing the canonical code hash is accepted as a genuine jetton wallet —
/// including an impersonator bound to an attacker's minter.
contract VulnerableJettonBridge {
    bytes32 public immutable canonicalWalletHash;
    mapping(address => mapping(string => uint256)) public credited; // user -> asset -> bridged
    mapping(string => uint256) public bridgedSupply;

    constructor(bytes32 _canonicalWalletHash) {
        canonicalWalletHash = _canonicalWalletHash;
    }

    function deposit(address senderWallet, string calldata asset, uint256 amount) external {
        // Verify the sender "is a jetton wallet" by code hash.
        require(senderWallet.codehash == canonicalWalletHash, "not a jetton wallet");
        // BUG: never checks JettonWallet(senderWallet).minter() == canonical minter for `asset`.
        // A code-hash match does NOT prove WHICH minter the wallet belongs to.
        credited[msg.sender][asset] += amount;
        bridgedSupply[asset] += amount;
    }
}

/// SAFE: code hash AND minter provenance. Structure proves it's a jetton wallet; provenance
/// proves it's THIS asset's wallet, bound to the canonical minter.
contract SafeJettonBridge {
    bytes32 public immutable canonicalWalletHash;
    mapping(string => address) public canonicalMinter; // asset -> expected jetton master
    mapping(address => mapping(string => uint256)) public credited;
    mapping(string => uint256) public bridgedSupply;

    constructor(bytes32 _canonicalWalletHash) {
        canonicalWalletHash = _canonicalWalletHash;
    }

    function setCanonicalMinter(string calldata asset, address minter) external {
        canonicalMinter[asset] = minter;
    }

    function deposit(address senderWallet, string calldata asset, uint256 amount) external {
        require(senderWallet.codehash == canonicalWalletHash, "not a jetton wallet");
        // FIX: verify the wallet's minter binding matches the canonical minter for the asset.
        address expected = canonicalMinter[asset];
        require(expected != address(0), "unknown asset");
        require(JettonWallet(senderWallet).minter() == expected, "wrong minter");
        credited[msg.sender][asset] += amount;
        bridgedSupply[asset] += amount;
    }
}
