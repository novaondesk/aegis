# Research Log — 2026-06-01 — Loopscale Case Study

## Done
- Wrote full case study for Loopscale RateX PT pricing exploit (April 2025)
  - File: `docs/exploits/loopscale-ratex-pricing-2025-04-26.md`
  - Sources: Loopscale post-mortem, Halborn analysis, Quadriga Initiative, on-chain tx
- Added 2 new items to `checklists/solana-anchor-checklist.md`:
  - CPI-Based Price Feed Validation (under Sysvar/Oracle Spoofing)
  - Integration Consistency (under Sysvar/Oracle Spoofing)
- Added 2 new items to `checklists/master-checklist.md` lending playbook:
  - External source identity validation for collateral pricing
  - Consistency across collateral type adapters
- Updated `docs/exploits/2026-recent-exploits.md`:
  - Added Loopscale to 2025 reference incidents table
  - Added pattern #5 about integration code being the weakest link
  - Checked off Loopscale in deep-dive backlog

## Takeaways
- **CPI target validation is Solana's "arbitrary external call."** Any protocol that calls
  into another program for pricing data must validate the callee's program ID. This is the
  single highest-signal check for Solana lending/AMM integrations.
- **Inconsistency between adapters is a reliable signal.** When one collateral type has
  validation checks that another doesn't, that's almost always a bug — especially if the
  less-validated type was added later.
- **Whitehat bounties work for solo attackers.** 10% bounty ($580K) recovered all $5.8M.
  But this only works against individual actors, not state-sponsored groups (DPRK/Lazarus).
- **The exploit was 2 weeks after launch.** Loopscale launched April 10, exploited April 26.
  Newly launched protocols with fresh integrations are highest-risk targets.

## Next
- [ ] Balancer V2 ComposableStablePool rounding deep-dive (next case study)
- [ ] Anchor PoC for CPI target spoofing pattern (Solana PoC track)
- [ ] Search Immunefi for active Solana lending programs with CPI-based pricing
