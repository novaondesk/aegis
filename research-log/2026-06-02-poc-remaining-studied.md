# Research Log — 2026-06-02 — PoCs: remaining studied entries (Balancer + 5 non-EVM)

## Done
- Ported the last six `studied` catalog entries to runnable Foundry PoCs — the catalog is
  now **10/10 coded**. Full suite: `forge test` → 21 passed / 0 failed (10 suites).
- **Balancer V2 rounding** (`poc/test/BalancerRounding.t.sol`, native EVM): scaled-balance
  constant-sum pool; `_upscale` rounds down and the vulnerable input-downscale also rounds
  down, so dust swaps undercharge (collapse to 0 on a fractional rate). 65 micro-swaps
  deflate invariant `D` (2500000 → 2499935) and extract token1 for free; safe variant
  rounds input up → `D` non-decreasing.
- **Cashio infinite-mint** (`CashioInfiniteMint.t.sol`, EVM model): relative-only account
  validation → fakes mint 2B CASH; safe anchors the mint to a trusted LP.
- **Cetus overflow** (`CetusOverflow.t.sol`, EVM model — EVM `<<` is modular like Move):
  wrong overflow boundary lets `2^192` pass, `<< 64` wraps to 0, deposit collapses to 0
  for a reserve-draining position; safe uses the correct boundary and reverts.
- **Loopscale spot-price oracle** (`LoopscaleOracle.t.sol`, EVM model): thin-pool spot
  price skewed in-tx ($1 → $100) → ~100× over-borrow; safe uses a reference price.
- **Loopscale unvalidated CPI** (`LoopscaleCpi.t.sol`, EVM model): borrower-supplied rate
  provider (arbitrary external-call target) spoofs PT price 1000× → over-borrow; safe pins
  a trusted provider.
- **Mango oracle manipulation** (`MangoOracle.t.sol`, EVM model): thin gov token at 100%
  weight, oracle spiked $1 → $576 → ~$5.76M drained; safe adds a deviation circuit breaker
  + per-asset cap + sub-100% weight (collateral *design* fix, deliberately distinct from
  the Loopscale-oracle fix which swaps the price source).
- Flipped all six catalog entries `studied → coded` with `poc`/`poc_cmd`; added a Runnable-
  PoC callout to each case study; updated `poc/README`, top `README` (status column, legend
  with an EVM-model note, "10/10 coded", Next).

## Takeaways
- Five of the six incidents are non-EVM (Solana/Sui-Move), but each reduces to a single
  Solidity-expressible invariant, so the Foundry harness reproduces them honestly. The
  README/docs label these "(EVM model)" and the catalog `chains` field still records the
  real chain — the model is the proof artifact, not a claim about where it happened.
- Account-validation bugs (Cashio, Loopscale-CPI) are the least native-faithful as EVM
  models: Solidity has no account model, so "missing mint anchor" becomes "missing address
  allowlist" and "unvalidated CPI" becomes "arbitrary external-call target". Faithful to
  the *invariant*, not the Solana mechanics — native Anchor ports remain the fidelity TODO.
- Cetus is the most faithful non-EVM port because EVM bit-shifts are modular exactly like
  Move's, so the silent-truncation root cause carries over 1:1.

## Next
- [ ] Native Anchor harness for Cashio / Loopscale-CPI (account-model fidelity).
- [ ] Native Move (Sui) harness for Cetus (`checked_shlw` in situ).
- [ ] Keep new catalog entries born `coded` (PoC-first) rather than `studied`-then-ported.
