# Research Log — 2026-06-03 — Transit Finance Legacy Contract

## Focus
Transit Finance legacy contract exploit ($1.88M, May 12, 2026) — contract lifecycle management as an attack surface.

## What I found
- Transit Finance was exploited for $1.88M through a legacy TransitMixSwapBridge contract on TRON
- The contract was deprecated in 2022 after a $21M exploit — same vulnerability
- "Deprecation" meant removing the frontend, not disabling the contract
- Users who approved the contract in 2022 still had active approvals 4 years later
- The attacker called the contract directly on-chain, bypassing the frontend
- This is the same attack class as SwapNet ($13.4M), Aperture Finance ($3.67M), and Ekubo ($1.4M) — arbitrary calldata + standing approvals
- The unique twist: the contract was **known to be vulnerable** for 3.5 years

## What I produced
1. **Case study:** `docs/exploits/transit-finance-legacy-2026-05-12.md` — full analysis with attack walkthrough, detection guidance, and key takeaways
2. **Checklist items:** Added X05 — Contract Lifecycle / Legacy Risk section with 3 new items:
   - X05-LEGACY-APPROVAL: Are user approvals revoked when deprecating a contract?
   - X05-LEGACY-PAUSE: Does every contract have a pause mechanism?
   - X05-LEGACY-SCAN: Is there a periodic scan for deprecated contracts with active approvals?
3. **Catalog entry:** `transit-finance-legacy-approval-drain` — 29th catalog entry, variant of approval-drain-arbitrary-call with legacy contract precondition
4. **Updated:** `docs/exploits/2026-recent-exploits.md` — added Transit Finance to the 2026 table

## Key insight
"Deprecated" is not a security property. On-chain contracts live forever. Deprecation is a social convention, not a technical one. The 2022 fix was a band-aid that left the wound open for 3.5 years. This is a systemic risk as more DeFi protocols "deprecate" contracts without actually disabling them.

## Next steps
- [ ] Create Foundry PoC for the legacy contract + approval drain pattern (requires TRON fork or EVM equivalent)
- [ ] Research how many other "deprecated" contracts on TRON/EVM still hold active approvals
- [ ] Consider adding a semgrep rule for contracts with `target.call(data)` but no pause mechanism
