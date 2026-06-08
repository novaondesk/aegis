# Research Log — 2026-06-08 — Flooring Protocol + BitmapPunks Ghost Ownership

## What I looked at
- web3isgoinggreat.com feed (Atom format) — 20 entries, all previously covered
- SlowMist Hacked database — found new June 2026 exploits
- Searched for DeFi exploits in June 2026 via web search

## What I found

### New exploits discovered (June 2026):
1. **Flooring Protocol** (2026-06-08) — Ghost ownership + underflow in packed fpToken accounting. $500K+ in NFTs. Yuga Labs rescued 68 NFTs via white-hat operation.
2. **BitmapPunks** (2026-06-08) — Same BT404 packed ownership vulnerability. Same day as Flooring.
3. **Ambient Finance** (2026-06-08) — $110.6K, accounting logic flaw in surplus collateral handling via flash loan + HotProxy/WarmPath/ColdPath cycling.
4. **Gravity Bridge** (2026-05-30) — $5.4M, but private key leakage (not code exploit). Skip.
5. **Gnosis Pay** (2026-06-01) — $3,421, Delay Module bug. Too small.
6. **ApeBond** (2026-06-03) — $87,402, Smart Contract Vulnerability on BSC.
7. **Flooring Protocol** (2026-06-07) — Also listed separately, same incident.

### Key insight: Packed Storage Inconsistency is a new vulnerability archetype
ERC-404, BT404, DN404 and similar semi-fungible token standards use bit-packed storage for
ownership and balance tracking. When two code paths read the same packed storage slot with
different bit masks or shifts, crafted token IDs can create "ghost ownership" states where
the ownership check passes but the accounting system disagrees. Combined with unchecked
packed arithmetic, this allows balance inflation via underflow.

This is the same class as DN404 vulnerabilities found by Guardian Audits in June 2024.

## What I produced
- Case study: `docs/exploits/flooring-protocol-ghost-ownership-2026-06-08.md` (full analysis)
- Case study: `docs/exploits/bitmappunks-bt404-underflow-2026-06-08.md` (related incident)
- PoC: `poc/test/FlooringGhostOwnership.t.sol` (Foundry test demonstrating ghost ownership + underflow)
- Catalog entry: `flooring-protocol-ghost-ownership` (SC09, SC02)
- Catalog entry: `bitmappunks-bt404-underflow` (SC09, SC02)
- Checklist item: SC09-PACKED-1 in master-checklist.md

## Takeaways
- Semi-fungible token standards are a systemic risk — the packed encoding pattern is complex
  and error-prone. Multiple implementations (Flooring, BitmapPunks, DN404) have had the same
  class of vulnerability.
- "Audited" doesn't mean "safe" — Flooring passed multiple audits. The bug was in gas-optimized
  bit-level code that hid the flaw from reviewers.
- AI-assisted exploit discovery is a real trend — Flooring's architect suspects the attacker
  used advanced AI tooling to find the edge case.

## Next steps
- [ ] Research Ambient Finance surplus collateral exploit in more detail
- [ ] Create semgrep rule for packed-storage-inconsistency pattern
- [ ] Look into Gravity Bridge exploit details (contract key compromise, not just private key)
- [ ] Check if there are more June 2026 exploits from other sources (DeFiHackLabs, BlockSec)
