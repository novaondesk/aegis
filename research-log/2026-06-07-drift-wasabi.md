# Research Log — 2026-06-07 — Drift Protocol + Wasabi Protocol Deep-Dives

## Focus
Phase 1: Case study from web3isgoinggreat.com — two unexplored code exploits from the RSS feed:
1. **Drift Protocol** ($285M, April 1, 2026) — largest DeFi exploit of 2026, Solana
2. **Wasabi Protocol** ($5.5M, April 30, 2026) — UUPS upgrade exploit, multi-chain

## What I Did

### Drift Protocol ($285M) — Oracle Manipulation + Governance Compromise
- Wrote full case study: `docs/exploits/drift-oracle-manipulation-2026-04-01.md`
- **Key code-level finding:** Oracle (Switchboard) accepted CarbonVote Token (CVT) with $500 in real liquidity as collateral worth hundreds of millions. No minimum liquidity validation — price without depth is meaningless.
- **Architecture failures:** Zero-timelock Security Council (removed 5 days pre-exploit), 2-of-5 multisig (social engineering of 2 signers), Solana durable nonce pre-signing for instant execution
- **Attribution:** DPRK/Lazarus Group (TRM Labs, Elliptic independent assessments)
- **Laundering:** $232M bridged Solana→Ethereum via Circle's CCTP in 100+ txs, converted to ~129K ETH. $0 recovered.
- Added 3 new Solana checklist items: SOL-ORACLE-4 (liquidity validation), SOL-GOVERNANCE-1 (timelock), SOL-GOVERNANCE-2 (multisig threshold)
- Added 2 new master checklist items: SC02-GOV-4 (multisig/timelock config), SC02-ORACLE-LIQUID-1 (oracle liquidity depth)
- New catalog entry: `drift-oracle-liquidity-manipulation`

### Wasabi Protocol ($5.5M) — UUPS Proxy Upgrade via Single-Owner Admin
- Wrote full case study: `docs/exploits/wasabi-protocol-uups-upgrade-2026-04-30.md`
- **Key finding:** Single EOA (`wasabideployer.eth`) held sole `ADMIN_ROLE` for UUPS upgrades. No timelock, no multisig. Attacker called `upgradeToAndCall()` to replace vault contracts with drainers across 4 chains.
- **Audit gap:** Both Zellic and Sherlock audits were technically correct but irrelevant — the exploit bypassed audited code entirely by replacing the implementation.
- Added 2 new master checklist items: SC10-UUPS-1 (upgrade authority gating), SC10-UUPS-2 (emergency pause)
- New catalog entry: `wasabi-protocol-uups-upgrade`

## Takeaways

1. **Price without liquidity is a fiction.** Every oracle integration should enforce minimum liquidity thresholds. This is the single most impactful checklist addition from this session — it's a pattern that applies to every perps/lending protocol.

2. **Audit scope must cover governance architecture.** Both Drift (2 audits) and Wasabi (2 audits) were exploited through governance/key management, not code. The industry's audit model is incomplete.

3. **UUPS is a loaded gun.** The UUPS pattern gives the proxy admin the ability to replace all contract logic at any time. When the admin is a single EOA with no timelock, the admin key security IS the protocol security.

4. **The web3isgoinggreat backlog is now mostly cleared.** All code exploits from the feed through May 2026 are now covered. Future runs should check for new entries or focus on other rotation areas (checklist enhancement, PoC development, target scouting).

## Files Modified
- `docs/exploits/drift-oracle-manipulation-2026-04-01.md` — NEW (Drift case study)
- `docs/exploits/wasabi-protocol-uups-upgrade-2026-04-30.md` — NEW (Wasabi case study)
- `catalog/exploits.yaml` — 2 new entries (drift-oracle-liquidity-manipulation, wasabi-protocol-uups-upgrade)
- `checklists/solana-anchor-checklist.md` — SOL-ORACLE-4, SOL-GOVERNANCE-1, SOL-GOVERNANCE-2 + new Governance section
- `checklists/master-checklist.md` — SC02-GOV-4, SC02-ORACLE-LIQUID-1, SC10-UUPS-1, SC10-UUPS-2
- `docs/exploits/2026-recent-exploits.md` — Updated Drift and Wasabi entries with deep-dive details
- `research-log/2026-06-07-drift-wasabi.md` — THIS FILE

## Stats
- Catalog entries: 39 → 41
- Case studies: 35 → 37
- Master checklist items: ~111 → ~115
- Solana checklist items: ~31 → ~34
