# Research Log — 2026-06-06 — TAC Bridge Jetton Impersonation

## Focus
Case study: TAC Bridge ($2.85M, 2026-05-11) — TON jetton wallet code-hash verification bypass.

## What I Did

1. **Feed scan:** Fetched web3isgoinggreat.com `?theme=hack` page. 10 entries total, all code exploits already studied except TAC Bridge (the only gap).

2. **Source research:** Found and read TAC's official post-mortem at `tac.build/blog/post-mortem-report-tac-bridge`. Key details:
   - Root cause: sequencer verified jetton wallet code hash but not minter binding
   - 302M fake BLUM minted in 5 transactions
   - Cross-chain liquidation across Ethereum, BSC, Solana, ZCash
   - ~90% recovered via white-hat bounty (attacker kept 13 ETH + 300 ZEC + 1,007 SOL)
   - TAC sequencer was audited March 2025, but TON docs subsequently elevated code-hash+minter to baseline requirement — TAC didn't track the change

3. **Case study written:** `docs/exploits/tac-bridge-jetton-impersonation-2026-05-11.md`
   - Full post-mortem analysis with vulnerable code reconstruction
   - Attack walkthrough with multi-chain fund flow
   - Detection guidance (static analysis won't catch it — bug is a missing check)
   - Reusable pattern: "Incomplete Provenance Verification" — verifying code but not context binding

4. **Catalog entry:** Added `tac-bridge-jetton-impersonation` as 35th entry (first TON-specific exploit in the catalog)

5. **Checklist items:** Added 3 new items to master-checklist:
   - SC02-BRIDGE-TON-1 (🤖): TON jetton wallet code hash + minter verification
   - SC02-BRIDGE-PROV-1 (👁): General cross-chain bridge provenance chain verification
   - SC02-MONITOR-1 (🤖): Per-minter rate limits and supply invariants as second-line defense

6. **Updated 2026-recent-exploits.md:** Filled in the TAC Bridge row (was placeholder), added to deep-dive backlog as done.

## Key Insight

The TAC Bridge exploit is a new archetype: **Incomplete Provenance Verification**. The bridge verified the *type* of the sender (canonical jetton wallet code hash) but not its *identity* (which minter it belongs to). This is the TON-specific version of a pattern that appears across all chains:
- **TON:** Code hash ≠ minter binding (TAC)
- **EVM:** Bytecode ≠ storage layout (proxy storage collision)
- **Solana:** Program ownership ≠ account data chain (Cashio)

The post-mortem's "Lessons Learned" section explicitly calls out that **rate-based monitoring is "possibly more important than audits"** — a strong signal for our SC02-MONITOR-1 checklist item.

## What's Next

All recent web3isgoinggreat.com code exploits are now studied. The catalog has 35 entries covering EVM, Solana, NEAR, and now TON. Next rotation should focus on:
- Checklist enhancement (add more TON-specific items)
- PoC development for provenance verification pattern
- Target scouting on Immunefi for TON-ecosystem programs
- Q1 2026 deep-dives (Step Finance, Truebit, Resolv)
