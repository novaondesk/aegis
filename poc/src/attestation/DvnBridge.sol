// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
}

/// Insufficient cross-chain attestation threshold — the Kelp DAO / LayerZero "1-of-1 DVN" class
/// (~$292M, 2026-04-18). A bridge releases funds when it has `threshold` valid attestations from a
/// verifier set. With a 1-of-1 configuration, compromising (or forging through) that single
/// verifier authorizes any release — there is no second, independent check to catch the forgery.
/// The same shape recurs in multisig bridges and oracle quorums. Fix: require >= 2 attestations
/// from distinct, independent verifiers.
///
/// See docs/exploits/kelp-dao-layerzero-dvn-2026-04-18.md

abstract contract DvnBridgeBase {
    IERC20 public immutable token;
    mapping(address => bool) public isVerifier;
    uint256 public immutable threshold;

    struct Sig {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    constructor(IERC20 t, address[] memory verifiers, uint256 _threshold) {
        token = t;
        for (uint256 i = 0; i < verifiers.length; i++) isVerifier[verifiers[i]] = true;
        threshold = _threshold;
    }

    /// Release `amount` to `to` if enough distinct verifiers attested to this message.
    function release(address to, uint256 amount, uint256 nonce, Sig[] calldata sigs) external {
        bytes32 h = keccak256(abi.encodePacked(address(this), to, amount, nonce));
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", h));

        uint256 valid;
        address last; // enforce strictly-increasing signer addresses -> distinct verifiers
        for (uint256 i = 0; i < sigs.length; i++) {
            address signer = ecrecover(ethHash, sigs[i].v, sigs[i].r, sigs[i].s);
            require(signer > last, "unsorted/duplicate");
            last = signer;
            if (isVerifier[signer]) valid++;
        }
        require(valid >= threshold, "insufficient attestations");
        token.transfer(to, amount);
    }
}

/// VULNERABLE: 1-of-1 — a single verifier's signature authorizes any release.
contract VulnerableDvnBridge is DvnBridgeBase {
    constructor(IERC20 t, address[] memory verifiers)
        DvnBridgeBase(t, verifiers, 1) // BUG: threshold of 1, single point of failure
    {}
}

/// SAFE: requires >= 2 distinct verifiers, so one compromised verifier cannot authorize a release.
contract SafeDvnBridge is DvnBridgeBase {
    constructor(IERC20 t, address[] memory verifiers)
        DvnBridgeBase(t, verifiers, 2) // >= 2 independent attestations
    {
        require(verifiers.length >= 2, "need >= 2 verifiers");
    }
}
