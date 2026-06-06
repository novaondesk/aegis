// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {ImpersonatorTwo} from "../src/levels/ImpersonatorTwo.sol";

/// Ethernaut "ImpersonatorTwo" → ECDSA nonce (k) reuse → private key recovery.
/// (catalog: new detector `ecdsa-nonce-reuse-key-extraction`).
///
/// The factory deploys the level and initializes it with TWO signatures from the
/// owner (Bob) that share the SAME `r` value:
///   SWITCH_LOCK_SIG  → signs "lock0"      (r, s1, v=27)
///   SET_ADMIN_SIG    → signs "admin1"||ADMIN (r, s2, v=27)
///
/// Same `r` = same ephemeral nonce `k`. With two (hash, sig) pairs sharing `k`:
///   k = (h1 − h2) · inv(s1 − s2)  (mod n)
///   d = (s1 · k − h1) · inv(r)    (mod n)
/// where `inv(x) = x^(n−2) mod n` via the modexp precompile (0x05).
///
/// Recover Bob's private key `d`, then `vm.sign(d, ...)` to forge signatures:
/// 1. `setAdmin` → make player admin
/// 2. `switchLock` → unlock the funds
/// 3. `withdraw` → drain the contract
/// Win: `instance.balance == 0`.
contract ImpersonatorTwoTest is Test {
    // secp256k1 group order
    uint256 constant N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;

    // secp256k1 half-order for low-s canonicalization
    uint256 constant HALF_N = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0;

    // Factory constants
    address constant OWNER = 0x03E2cf81BBE61D1fD1421aFF98e8605a5A9e953a;
    address constant ADMIN = 0xADa4aFfe581d1A31d7F75E1c5a3A98b2D4C40f68;
    bytes32 constant R = 0xe5648161e95dbf2bfc687b72b745269fa906031e2108118050aba59524a23c40;
    bytes32 constant S1 = 0x70026fc30e4e02a15468de57155b080f405bd5b88af05412a9c3217e028537e3;
    bytes32 constant S2 = 0x4c3ac03b268ae1d2aca1201e8a936adf578a8b95a49986d54de87cd0ccb68a79;

    // Exact message hashes from contract's hash_message (computed via test_get_hashes)
    bytes32 constant H1 = 0x937fa99fb61f6cd81c00ddda80cc218c11c9a731d54ce8859cb2309c77b79bf3; // "lock0"
    bytes32 constant H2 = 0x6a0d6cd0c2ca5d901d94d52e8d9484e4452a3668ae20d63088909611a7dccc51; // "admin1" + ADMIN

    // Pre-computed modular inverses (offline)
    uint256 constant INV_S1_MINUS_S2 = 0xc8041b524428826c5bae4ec0ecebf1fd19bc247762c83bd7c401b323dba6f9c1;
    uint256 constant INV_R = 0x486c30387cebd5836eeb39967716357a0280efa5b8fe432779c67471c3f71e66;

    // Pre-computed private key (offline: k-reuse recovery)
    uint256 constant PRIVATE_KEY = 0x10a6891de55baf453d66c5faede86eabccf93f3d284540d205f24207670855cc;

    function _canonicalize(bytes32 r, bytes32 s, uint8 v) internal pure returns (bytes32, bytes32, uint8) {
        // Ensure low-s (ECDSA shim rejects high-s)
        if (uint256(s) > HALF_N) {
            return (r, bytes32(N - uint256(s)), v == 27 ? 28 : 27);
        }
        return (r, s, v);
    }

    function test_solve_impersonator_two() public {
        // --- challenge setup: mirror the factory ---
        ImpersonatorTwo instance = new ImpersonatorTwo{value: 0.001 ether}();
        instance.transferOwnership(OWNER);
        // Mirror factory initialization: switchLock("lock0") then setAdmin("admin1"+ADMIN),
        // both signed by the owner with the SAME r (this is the vulnerability). 65-byte sigs.
        bytes memory switchLockSig = abi.encodePacked(R, S1, uint8(27));
        instance.switchLock(switchLockSig);
        bytes memory setAdminSig = abi.encodePacked(R, S2, uint8(27));
        instance.setAdmin(setAdminSig, ADMIN);
        assertEq(instance.nonce(), 2, "nonce should be 2 after factory init");
        assertEq(instance.admin(), ADMIN, "admin should be ADMIN after factory init");

        // --- verify pre-computed private key recovers owner ---
        address recovered = vm.addr(PRIVATE_KEY);
        assertEq(recovered, OWNER, "pre-computed private key matches owner");

        // --- forge signatures as the owner ---
        // 1. setAdmin: make player admin (nonce = 2)
        bytes32 msgAdmin = instance.hash_message(string(abi.encodePacked("admin2", address(this))));
        (uint8 vAdmin, bytes32 rAdmin, bytes32 sAdmin) = vm.sign(PRIVATE_KEY, msgAdmin);
        (rAdmin, sAdmin, vAdmin) = _canonicalize(rAdmin, sAdmin, vAdmin);
        bytes memory sigAdmin = abi.encodePacked(rAdmin, sAdmin, vAdmin);
        instance.setAdmin(sigAdmin, address(this));
        assertEq(instance.admin(), address(this), "player is now admin");

        // 2. switchLock: unlock (nonce = 3)
        bytes32 msgLock = instance.hash_message("lock3");
        (uint8 vLock, bytes32 rLock, bytes32 sLock) = vm.sign(PRIVATE_KEY, msgLock);
        (rLock, sLock, vLock) = _canonicalize(rLock, sLock, vLock);
        bytes memory sigLock = abi.encodePacked(rLock, sLock, vLock);
        instance.switchLock(sigLock);

        // 3. withdraw: drain balance (player is admin, funds unlocked)
        instance.withdraw();

        // Win condition: instance.balance == 0
        assertEq(address(instance).balance, 0, "contract drained");
    }

    // Allow this test contract (the "player"/admin) to receive the withdrawn ether.
    receive() external payable {}
}