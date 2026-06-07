#!/usr/bin/env python3
"""
EllipticToken — derive the forged permit values used in test/EllipticToken.t.sol.

The attack is a raw-ECDSA existential forgery. It uses ONLY ALICE's PUBLIC key, which is
recoverable from her PUBLIC voucher signature hardcoded in EllipticTokenFactory — never her
private key. Given ALICE's public key Q:

    pick a, b ; P = a*G + b*Q ; r = P.x mod n ; s = r * b^-1 mod n ; z = a*s mod n ; v = 27 + (P.y & 1)

Then ecrecover(z, v, r, s) == ALICE over the message z (which we computed, != voucherHash), so the
contract's `usedHashes[bytes32(amount)]` guard (amount = z) is not set. permit() then approves
ALICE -> attacker for `amount = z`, and transferFrom drains ALICE.

Run:  python3 elliptic_forge.py   (needs: pip install ecdsa web3)
"""
from web3 import Web3
from ecdsa import SECP256k1
from ecdsa.ellipticcurve import Point

G, n, curve = SECP256k1.generator, SECP256k1.order, SECP256k1.curve
ALICE = "0xA11CE84AcB91Ac59B0A4E2945C9157eF3Ab17D4e"
AMOUNT = 10 * 10**18
SALT = Web3.keccak(text="BOB and ALICE are part of the secret sauce")
# ALICE's PUBLIC voucher signature, verbatim from EllipticTokenFactory.createInstance:
ALICE_SIG = bytes.fromhex(
    "ab1dcd2a2a1c697715a62eb6522b7999d04aa952ffa2619988737ee675d9494f"
    "2b50ecce40040bcb29b5a8ca1da875968085f22b7c0a50f29a4851396251de12"
    "1c"
)

# 1. Recover ALICE's public key Q from her public voucher signature (no private key involved).
voucher_hash = Web3.keccak(AMOUNT.to_bytes(32, "big") + bytes.fromhex(ALICE[2:]) + SALT)
z0 = int.from_bytes(voucher_hash, "big")
r0, s0, v0 = int.from_bytes(ALICE_SIG[:32], "big"), int.from_bytes(ALICE_SIG[32:64], "big"), ALICE_SIG[64]
x = r0
alpha = (x**3 + 7) % curve.p()
y = pow(alpha, (curve.p() + 1) // 4, curve.p())
if (y & 1) != ((v0 - 27) & 1):
    y = curve.p() - y
R0 = Point(curve, x, y)
Q = pow(r0, -1, n) * (s0 * R0 + (n - (z0 % n)) * G)
addr = "0x" + Web3.keccak(Q.x().to_bytes(32, "big") + Q.y().to_bytes(32, "big")).hex()[-40:]
assert Web3.to_checksum_address(addr) == Web3.to_checksum_address(ALICE), "pubkey recovery mismatch"

# 2. Existential forgery from Q.
a, b = 0x1337, 0xBEEF
P = a * G + b * Q
r = P.x() % n
s = (r * pow(b, -1, n)) % n
z = (a * s) % n
v = 27 + (P.y() & 1)
assert s < n // 2, "need low-s (OZ ECDSA rejects high-s)"  # bump a,b if this trips

print("amount (z) =", hex(z))
print("r          = 0x%064x" % r)
print("s          = 0x%064x" % s)
print("v          =", v)
