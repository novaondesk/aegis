// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {EllipticToken} from "../src/levels/EllipticToken.sol";

/// Ethernaut "EllipticToken" → ECDSA existential forgery (raw-message signature forgery).
/// (catalog: `signature-replay-malleability` family — here, raw-ECDSA selective forgery.)
///
/// Win: `balanceOf(ALICE) == 0`. ALICE holds 10 ETK; the only lever to move them is `permit`,
/// which sets `_approve(tokenOwner, spender, amount)` with
///   tokenOwner = ECDSA.recover(bytes32(amount), tokenOwnerSignature)
/// so we must make `recover(...) == ALICE`. The naive path — reuse ALICE's voucher signature —
/// forces `amount == voucherHash`, but `usedHashes[voucherHash]` is already set (redeemVoucher),
/// so `require(!usedHashes[bytes32(amount)])` reverts.
///
/// THE INSIGHT: raw ECDSA over an UNCONSTRAINED message is existentially forgeable. Given ALICE's
/// PUBLIC key Q (recoverable from her public on-chain voucher signature — no private key needed),
/// pick a,b and set P = a·G + b·Q, r = P.x, s = r·b⁻¹, z = a·s, v = 27+(P.y&1). Then
/// ecrecover(z, v, r, s) == ALICE over the message z that WE computed (z != voucherHash), so
/// `usedHashes[z]` is false. `permit` then approves ALICE→attacker for `amount = z` (huge), and
/// transferFrom drains ALICE. The forged (z, r, s, v) below were computed offline from ALICE's
/// public voucher signature; see script/elliptic_forge.py for the derivation.
contract EllipticTokenTest is Test {
    EllipticToken instance;
    address constant BOB = 0xB0B14927389CB009E0aabedC271AC29320156Eb8;
    address constant ALICE = 0xA11CE84AcB91Ac59B0A4E2945C9157eF3Ab17D4e;
    uint256 constant INITIAL_AMOUNT = 10 ether;

    address attacker;
    uint256 attackerKey;

    function setUp() public {
        // Mimic EllipticTokenFactory.createInstance verbatim.
        instance = new EllipticToken();
        instance.transferOwnership(BOB);
        bytes memory bobSignature =
            hex"085a4f70d03930425d3d92b19b9d4e37672a9224ee2cd68381a9854bb3673ef86b35cfdeee0fb1d2168587fb188eefb4fe046109af063bf85d9d3d6859ceb4451c";
        bytes memory aliceSignature =
            hex"ab1dcd2a2a1c697715a62eb6522b7999d04aa952ffa2619988737ee675d9494f2b50ecce40040bcb29b5a8ca1da875968085f22b7c0a50f29a4851396251de121c";
        bytes32 salt = keccak256("BOB and ALICE are part of the secret sauce");
        instance.redeemVoucher(INITIAL_AMOUNT, ALICE, salt, bobSignature, aliceSignature);

        (attacker, attackerKey) = makeAddrAndKey("attacker");
    }

    function test_solve_elliptic_token() public {
        assertEq(instance.balanceOf(ALICE), INITIAL_AMOUNT, "ALICE starts with 10 ETK");

        // Forged permit: recovers ALICE over a fresh message z (computed from ALICE's PUBLIC key).
        uint256 amount = 0x25e9a3cf5399963b099544addba30394e95189ac29e177f6491c9d0584bd27d6;
        bytes32 r = 0xa5a48b77287dd596ad3ccdaeac6bb8a55b92f5d217cc786159453a7a98828d9e;
        bytes32 s = 0x7ea0e9a79ef4e4dd31f69c4ca48d89cef3199d95a0c36d767e10efe0a22f2ba1;
        uint8 v = 27;
        bytes memory ownerSig = abi.encodePacked(r, s, v);

        // The spender (attacker) accepts: sign keccak256(abi.encodePacked(tokenOwner, spender, amount)).
        bytes32 acceptHash = keccak256(abi.encodePacked(ALICE, attacker, amount));
        (uint8 av, bytes32 ar, bytes32 as_) = vm.sign(attackerKey, acceptHash);
        bytes memory spenderSig = abi.encodePacked(ar, as_, av);

        // permit -> _approve(ALICE, attacker, amount). z != voucherHash, so usedHashes[z] is false.
        instance.permit(amount, attacker, ownerSig, spenderSig);
        assertGe(instance.allowance(ALICE, attacker), INITIAL_AMOUNT, "ALICE approved the attacker");

        // Drain ALICE.
        vm.prank(attacker);
        instance.transferFrom(ALICE, attacker, INITIAL_AMOUNT);

        assertEq(instance.balanceOf(ALICE), 0, "win: balanceOf(ALICE) == 0");
        assertEq(instance.balanceOf(attacker), INITIAL_AMOUNT, "tokens moved to attacker");
    }
}
