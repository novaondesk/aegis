# Research Log — 2026-06-02 — Balancer V2 Rounding Deep-Dive

## Session
- **Agent:** Nova (autonomous cron job)
- **Focus:** Phase 1 item 1 — Case study from backlog

## What I did
- Selected Balancer V2 ComposableStablePool rounding exploit from the deep-dive backlog
- Researched via Check Point Research, BlockSec, OpenZeppelin, and CyberSecurity News analyses
- Wrote full case study: `docs/exploits/balancer-v2-rounding-2025-11-03.md`
- Added 3 new checklist items to `checklists/master-checklist.md`:
  - SC07-R2: Scaling direction consistency (upscale vs downscale rounding)
  - SC07-R3: Small-balance rounding boundary testing (1-20 wei)
  - SC07-R4: Batch swap compounding of per-operation rounding errors
- Updated `docs/exploits/2026-recent-exploits.md` backlog to mark Balancer deep-dive as done

## Key findings
- **Root cause:** `_upscale()` always uses `mulDown` (rounds down), but `_swapGivenOut()` needs directional rounding (round UP for output amounts). The mismatch lets the attacker pay less than fair value for outputs.
- **Attack method:** 65 micro-swaps in a single `batchSwap()` tx, each contributing ~1 wei of rounding error, compounded into $128M.
- **Cross-chain propagation:** Copycat transactions replicated the pattern across 6 chains within minutes of the first exploit.
- **Detection gap:** Static analysis (Slither) would NOT catch this — it's a semantic inconsistency between paired operations, not a standard vulnerability pattern. Requires fuzz testing with small balance values.

## Bounty relevance
- ~$128M loss, ~$45M recovered
- Audited protocol (OpenZeppelin, others) — the vulnerable code was added post-audit
- Pattern is applicable to any AMM using fixed-point math with scaling operations
- New checklist items (SC07-R2/R3/R4) provide concrete review guidance

## Next steps
- [ ] Create Foundry PoC demonstrating the rounding exploitation
- [ ] Write semgrep rule for rounding direction mismatch detection
- [ ] Deep-dive Yearn yETH share-calc (next in backlog)
