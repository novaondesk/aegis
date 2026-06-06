# 2026-06-06 — Solve Ethernaut MagicAnimalCarousel (bit-packing / XOR corruption)

## Scope
Deferred level #4 (per CONTINUE.md). Self-contained bit-packing puzzle, no external shims.

## The bug
Crate `uint256` packs `[255..176] animal | [175..160] nextId | [159..0] owner`. `setAnimalAndSpin`
writes the target crate's animal with **XOR** (`(crate & ~NEXT_ID_MASK) ^ (animal << 176)`), keeping
any existing animal bits. So if the validator's `setAnimalAndSpin("Goat")` lands on a crate that
already holds animal bits, the stored value becomes `existing ^ Goat != Goat`. `validateInstance`
wins exactly on `carousel(currentCrateId) >> 176 != Goat`.

## The hard part (documented for the next reader)
You must make the validator's spin TARGET a pre-filled crate, i.e. `carousel[currentCrateId].nextId`
must point at one. `changeAnimal`'s `encodedAnimal << 160` **ORs** into the nextId field, and OR can
only *set* bits — so you can't point a crate "backward" to a lower, already-filled index. Spins also
march `currentCrateId` forward (`nextId = (id+1) % MAX_CAPACITY`), always to a fresh empty crate.

**Resolution:** use the `% MAX_CAPACITY` (65535) wrap. Routing a spin into crate **65534** stores
`nextId = 65535 % 65535 = 0` — a pointer back to crate **0**, which the constructor pre-initializes
(so `changeAnimal` works on it) and which has **no owner** (so `changeAnimal(.,0)` is unguarded).

## Solve sequence (player = test contract)
1. `setAnimalAndSpin("A1")` → fills crate 1 (nextId=2, owner=player), currentCrateId=1.
2. `changeAnimal(name1, 1)` with `name1` crafted so `encodeAnimalName(name1) & 0xFFFF == 0xFFFE`
   (bytes pack big-endian: low-16 = `name[10]<<8 | name[11]`). `0xFFFE | 2 == 0xFFFE` ⇒ crate 1 nextId = 65534.
3. `setAnimalAndSpin("A2")` → targets 65534; its nextId wraps to 0; currentCrateId = 65534.
4. `changeAnimal("Zz", 0)` → crate 0 (unguarded) gets nonzero animal bits.
5. [validator] `setAnimalAndSpin("Goat")` → targets crate 0 → XOR corrupts → `animal != Goat` → WIN.

## Done
- Vendored `ethernaut/src/levels/MagicAnimalCarousel.sol` (verbatim from OZ, `^0.8.28`, no imports).
- `ethernaut/test/MagicAnimalCarousel.t.sol` with a byte→field sanity assert + the solve.
  `forge test --match-contract MagicAnimalCarouselTest` (isolation, `--skip` old-solc) → **PASS** (gas 74,469).
- Counts 35 → **36 / 40** in README + wargame doc; row flipped to ✅. Bit-encoding remains a **catalog gap**
  (detector candidate).

## Next
EllipticToken (permit/voucher domain confusion), then the EIP-7702 pair (UniqueNFT, Cashback),
then NotOptimisticPortal. Full ethernaut aggregate run still pending Rosetta 2.
