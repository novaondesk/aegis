# 2026-06-02 — Mango Markets Oracle Manipulation Case Study

## What we did
- Wrote a deep-dive case study of the Mango Markets $114M oracle manipulation exploit (Oct 2022, Solana).
- Added 3 new checklist items to `checklists/master-checklist.md` under SC03 (Oracle Manipulation):
  - SC03-MANGO-1: Endogenous oracle / self-referential pricing loop
  - SC03-MANGO-2: Circuit breakers / deviation bounds
  - SC03-MANGO-3: Cross-margin collateral isolation
- Created `checklists/solana-anchor-checklist.md` (31 items across 7 categories) — the Solana/Anchor-specific checklist that was referenced in vault notes but didn't exist in the repo.

## Key takeaways
- **Mango Markets is the canonical "code correct, model broken" exploit.** The contracts executed their logic perfectly; the flaw was using a low-liquidity governance token as cross-margin collateral with no circuit breakers or position limits. Formal verification would have passed.
- **Self-referential pricing loops are the critical pattern.** When a protocol's oracle derives from markets the protocol itself facilitates, an attacker can manipulate the price on the very platform that uses it for collateral valuation. This is a composability failure, not a code bug.
- **Circuit breakers are the cheapest mitigation.** A simple "halt borrowing if oracle price moves >X% in Y minutes" would have prevented the entire $114M loss. This is now standard in Aave V3 and Compound V3.
- **Cross-margin without asset isolation is a design smell.** If a single manipulated asset can unlock borrowing against all other assets, the protocol has a single point of failure in its collateral model.
- **The formal verification blind spot is real.** ChainScore's analysis confirms: formal models treat oracles as black-box truth, creating a critical gap for cross-protocol state. This is the highest-value area for our checklist — tools can't catch it, humans can.

## Detection value
- **Static analysis**: Would NOT have flagged this (no code bug).
- **Our checklist**: The 3 new SC03 items directly target this pattern. A reviewer walking the checklist would ask "is the oracle endogenous?" and immediately flag the self-referential loop.
- **Bounty relevance**: This class of bug (oracle manipulation via economic model flaw) is the highest-value class for bounties on perps/lending platforms. $100K-$1M bounty range on Immunefi for Solana perps platforms.

## Next actions
- [ ] Add a Foundry invariant template for oracle manipulation stress-testing (treating oracle as attacker-controllable input).
- [ ] Write a semgrep rule that flags oracle price reads used in collateral valuation without deviation checks.
- [ ] Deep-dive: Balancer V2 ComposableStablePool rounding (from backlog).
- [ ] Target scouting: 3-5 Solana active Immunefi programs (from vault TODO).
