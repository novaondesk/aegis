# 2026-06-05 — Fix ImpersonatorTwo (k-reuse) + review handoff

## Context
Picked up the CONTINUE.md handoff. Reviewed the prior contributor's in-progress work on the
6 deferred Ethernaut levels (starting with ImpersonatorTwo, level #1).

## Found (review)
- The committed `ethernaut/test/ImpersonatorTwo.t.sol` **never passed**:
  - It assumed `nonce == 2` (post factory-init) but never performed the factory's
    `switchLock("lock0")` + `setAdmin("admin1"+ADMIN)` calls, so `setAdmin("admin2"+player)`
    reverted with `InvalidSignature` at `nonce == 0`.
  - It encoded `v` as `bytes32(uint256(v))` → a **96-byte** signature; `ECDSA.recover` wants 65.
- The uncommitted working-tree edits had the right ideas (factory-init mirroring, low-s
  canonicalization, 65-byte encoding) but **did not compile**: `bytes32 sig = abi.encodePacked(...)`
  (type mismatch — `abi.encodePacked` is `bytes memory`) and a call to a non-existent public
  `locked()` getter (`locked` is private). A duplicate `withdraw()`/assert block was left in.
- Separately, 10 unrelated files (the older 0.5/0.6 levels + their `oz06` vendor shims) had been
  **deleted in the working tree** — restored; they're needed by the other 34 levels.

## Fixed
- Rewrote the test faithfully: deploy + `transferOwnership(OWNER)` → mirror factory init with the
  real shared-`r` sigs `(R,S1,27)`/`(R,S2,27)` (nonce→2, admin=ADMIN) → recover the owner key from
  the offline k-reuse math → forge `setAdmin(player)` (nonce 2) → `switchLock` unlock (nonce 3) →
  `withdraw` → assert `instance.balance == 0`. Added `receive()` so the test contract (the admin)
  can take the drained ether. Kept the low-s `_canonicalize` guard (the OZ ECDSA shim rejects high-s).
- `cd ethernaut && forge test --match-contract ImpersonatorTwoTest` → **PASS** (gas 661,907).
- Bumped counts 34 → **35 / 40** in `ethernaut/README.md` + `docs/ethernaut-wargame.md`; flipped the
  ImpersonatorTwo row to ✅ solved and mapped it to the new `ecdsa-nonce-reuse-key-extraction` detector.

## Environment caveat (important)
This machine is **Apple Silicon with no Rosetta 2**, so the x86-only `solc` 0.5.x/0.6.x binaries the
older levels pin **cannot run here** — the *full* `ethernaut` suite can't compile on this host. The
ImpersonatorTwo fix was verified **in isolation** (`--skip` the old-solc files); the older 34 levels
are byte-identical to HEAD (restored, untouched). Aggregate `cd ethernaut && forge test` should be
re-run on a Rosetta-equipped host to confirm 35/35. `poc` suite (all `^0.8.20`) verified green: **64/64**.

## Next
- Add the full `ecdsa-nonce-reuse-key-extraction` catalog unit (case study + catalog entry +
  Vulnerable/Safe/test in `poc/` + checklist + semgrep) per AGENTS.md's four-places rule.
- Continue the deferred levels: MagicAnimalCarousel (self-contained), EllipticToken, then the
  EIP-7702 pair (UniqueNFT, Cashback), then NotOptimisticPortal.
