// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// Signature replay + malleability: a contract authorizes a transfer from an off-chain signer's
/// signature but (a) binds nothing to a nonce / domain, so the same signature can be replayed to
/// drain the contract, and (b) calls raw `ecrecover` without rejecting high-s values, so a second
/// valid signature exists for the same message (malleability) — defeating naive used-signature
/// dedup. Fix: EIP-712 domain + per-account nonce + s-value/zero-address checks.
///
/// See docs/exploits/signature-replay-malleability.md

/// VULNERABLE: no nonce, no domain separator, no s-check.
contract VulnerableClaim {
    address public immutable signer;

    constructor(address s) payable {
        signer = s;
    }

    function claim(address to, uint256 amount, uint8 v, bytes32 r, bytes32 s) external {
        bytes32 h = keccak256(abi.encodePacked(to, amount));
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", h));
        address rec = ecrecover(ethHash, v, r, s);
        require(rec == signer, "bad sig"); // BUG: replayable + malleable; no nonce, no s-check
        (bool ok,) = to.call{value: amount}("");
        require(ok, "transfer failed");
    }
}

/// SAFE: EIP-712 typed data with a per-recipient nonce (consumed on use → no replay), an explicit
/// low-s requirement (rejects the malleable counterpart), and a zero-address recover guard.
contract SafeClaim {
    address public immutable signer;
    bytes32 public immutable DOMAIN_SEPARATOR;
    mapping(address => uint256) public nonces;

    bytes32 private constant TYPEHASH =
        keccak256("Claim(address to,uint256 amount,uint256 nonce)");
    // secp256k1n / 2
    uint256 private constant HALF_N =
        0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0;

    constructor(address s) payable {
        signer = s;
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("SafeClaim")),
                block.chainid,
                address(this)
            )
        );
    }

    function claim(address to, uint256 amount, uint8 v, bytes32 r, bytes32 s) external {
        require(uint256(s) <= HALF_N, "malleable s");
        uint256 nonce = nonces[to];
        bytes32 structHash = keccak256(abi.encode(TYPEHASH, to, amount, nonce));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        address rec = ecrecover(digest, v, r, s);
        require(rec != address(0) && rec == signer, "bad sig");
        nonces[to] = nonce + 1; // consume the nonce -> the same signature can't be replayed
        (bool ok,) = to.call{value: amount}("");
        require(ok, "transfer failed");
    }
}
