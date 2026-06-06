// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// ECDSA nonce (k) reuse → private-key extraction.
///
/// ECDSA signs as  s = k^-1 (h + r*d) mod n , where k is a per-signature secret nonce and
/// r = (k*G).x. If a signer ever reuses the SAME k for two different messages, both signatures
/// carry the SAME r, and anyone who sees the two (r, s, h) pairs recovers the long-term key d:
///
///     k = (h1 - h2) * inv(s1 - s2)  (mod n)
///     d = (s1*k - h1) * inv(r)      (mod n)
///
/// This is NOT a malleability/replay bug and NO on-chain check prevents it — the defect is the
/// signer's nonce discipline (use RFC-6979 / a CSPRNG; never reuse k). Once d leaks, every
/// signature-gated action that trusts that key is forgeable. Famous instances: the 2010 Sony
/// PS3 ECDSA key recovery (fixed k) and assorted wallet/bridge signer compromises.
library EcdsaNonceReuse {
    // secp256k1 group order n
    uint256 internal constant N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;

    /// Modular inverse via Fermat (a^(n-2) mod n) using the modexp precompile (0x05).
    function inv(uint256 a) internal view returns (uint256 result) {
        uint256 e = N - 2;
        uint256 m = N;
        assembly {
            let p := mload(0x40)
            mstore(p, 0x20) // length of base
            mstore(add(p, 0x20), 0x20) // length of exponent
            mstore(add(p, 0x40), 0x20) // length of modulus
            mstore(add(p, 0x60), a) // base
            mstore(add(p, 0x80), e) // exponent
            mstore(add(p, 0xa0), m) // modulus
            if iszero(staticcall(gas(), 0x05, p, 0xc0, p, 0x20)) { revert(0, 0) }
            result := mload(p)
        }
    }

    /// Recover the signer's private key from two signatures that reuse the same nonce k
    /// (hence share r). h1,h2 must be the message digests reduced mod n; r,s1,s2 as signed.
    function recoverPrivateKey(uint256 h1, uint256 h2, uint256 r, uint256 s1, uint256 s2)
        internal
        view
        returns (uint256 d)
    {
        uint256 num = addmod(h1, N - h2, N); // h1 - h2
        uint256 den = addmod(s1, N - s2, N); // s1 - s2
        uint256 k = mulmod(num, inv(den), N); // k = (h1-h2)/(s1-s2)
        uint256 t = addmod(mulmod(s1, k, N), N - (h1 % N), N); // s1*k - h1
        d = mulmod(t, inv(r), N); // d = (s1*k - h1)/r
    }
}

/// A minimal victim: a vault whose privileged `release` is authorized by an ECDSA signature
/// from a fixed off-chain `signer` over (recipient, amount, nonce). The message binds a consumed
/// nonce and the contract address, so it is replay- and malleability-safe (an OZ-style gate).
/// It is still fully drainable if `signer` ever reused a k elsewhere and leaked its key — the
/// forged signature is, by construction, indistinguishable from a genuine one.
contract SignerGatedVault {
    address public immutable signer;
    uint256 public nonce;

    constructor(address _signer) payable {
        signer = _signer;
    }

    function _digest(address to, uint256 amount, uint256 n) public view returns (bytes32) {
        bytes32 inner = keccak256(abi.encodePacked(address(this), to, amount, n));
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", inner));
    }

    /// Releases `amount` to `to` if the signature recovers to `signer`. Nonce-bound (no replay),
    /// but it trusts whatever address `signer` is — so a recovered/forged key wins.
    function release(address to, uint256 amount, uint8 v, bytes32 r, bytes32 s) external {
        bytes32 h = _digest(to, amount, nonce);
        address rec = ecrecover(h, v, r, s);
        require(rec != address(0) && rec == signer, "bad sig");
        unchecked {
            ++nonce;
        }
        (bool ok,) = to.call{value: amount}("");
        require(ok, "transfer failed");
    }

    receive() external payable {}
}
