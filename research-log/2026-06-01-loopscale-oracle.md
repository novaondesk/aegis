# Research Log — 2026-06-01 — Loopscale Oracle Case Study

## Done
- Wrote deep-dive case study for Loopscale exploit (April 2025, $5.8M)
  - File: `docs/exploits/loopscale-oracle-2025-04.md`
  - Root cause: spot-price oracle manipulation of RateX PT collateral, no TWAP/multi-source
  - Attacker used flash loans to skew pool price, took undercollateralized loans
  - Funds returned after 10% white-hat bounty negotiation
- Created `checklists/solana-anchor-checklist.md` with 14 items across 7 categories
  - Oracle (3), Account Validation (3), Signer/Authority (2), CPI (1), Reinit/Lifecycle (2), Arithmetic (2), Sysvar (1)
  - SOL-ORACLE-1 directly derived from Loopscale case study
- Updated `docs/exploits/2026-recent-exploits.md` with Loopscale entry + deep-dive link

## Takeaways
- Oracle manipulation on Solana follows the same patterns as EVM — spot price from thin pool, no TWAP, flash-loan-aware attack
- Solana-specific twist: Anchor programs may not have easy access to Pyth/Switchboard TWAP, making developers more likely to roll their own pricing
- Loopscale was audited by OShield but the oracle design was missed — this is an architecture-level bug, not a code-level bug
- The 10% bounty return ($580K) shows white-hat economics can work when the attacker isn't a state actor

## Next
- [ ] PoC for SOL-ORACLE-1: write a minimal Anchor program with vulnerable spot-price oracle + test that demonstrates manipulation
- [ ] Add Loopscale-style oracle detection to `tools/semgrep/` (detect direct spot-price usage in loan/collateral functions)
- [ ] Target scouting: find 3-5 active Solana bounty programs on Immunefi (Marinade, Jupiter, Drift, Kamino, Marginfi)
- [ ] Deep-dive backlog: Balancer V2 rounding, Yearn yETH share-calc, Beanstalk governance flash-loan
