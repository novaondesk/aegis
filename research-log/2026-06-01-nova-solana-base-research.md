# 2026-06-01 — Solana + Base Research Sprint (Nova)

## What we did

### Solana / Anchor Security Research
- Mapped the Solana attack surface from canonical sources (Helius, Neodyme, Anchor docs, Sealevel attacks)
- Created comprehensive checklist (`checklists/solana-anchor-checklist.md`) with 20+ items covering:
  - Account validation (signer, owner, type cosplay, has_one, arbitrary CPI, PDA bump, duplicate mutable)
  - Integer overflow/underflow (Rust release mode wrapping, precision loss)
  - Account lifecycle (reinitialization, closing/revival, data matching, reloading)
  - CPI security (arbitrary target, privilege escalation)
  - PDA security (sharing, seed collisions)
  - Sysvar/oracle spoofing
  - Signer validation
  - Rust-specific issues (unsafe code, panic handling)
- Key insight: **Anchor eliminates account-level vulnerabilities systematically**, but logic-level and economic-level vulnerabilities require manual review
- Notable finding: 2026 nine-figure Solana exploits (Drift $270M) moved off-chain — durable-nonce abuse pattern in operations layer, not in Anchor

### Base / OP-Stack L2 Security Research
- Mapped Base-specific risks from OP Stack docs, Chainlink L2 sequencer feeds, industry reports
- Created addendum checklist (`checklists/base-l2-addendum.md`) with 15+ items covering:
  - Sequencer uptime & oracle freshness (downtime detection, staleness, grace period)
  - Cross-domain messaging (xDomainMessageSender verification, address aliasing, replay protection)
  - Block & time semantics (L2 block time, cross-chain timing)
  - Gas economics (cheap gas griefing, gas price manipulation)
  - Token assumptions (native vs bridged USDC, FoT tokens, OP-Stack predeploys)
  - Withdrawal & finalization (7-day window, fault proof assumptions)
  - L2-specific attack vectors (sequencer MEV, L1→L2 message failure)
- Key insight: **L2 sequencer uptime feed is critical** — missing it allows stale price exploitation during sequencer downtime
- Notable finding: Address aliasing for L1→L2 calls is a common missed check (offset: `0x1111000000000000000000000000000000001111`)

## Key takeaways
1. **Solana bugs are moving to logic/economic layer** — Anchor framework handles account validation well, but business logic bugs remain
2. **Base L2 requires fresh mental model** — sequencer assumptions, cross-domain messaging, gas economics all differ from L1
3. **Oracle staleness on L2 is highest-signal finding area** — sequencer downtime + stale prices = easy wins
4. **Cross-domain message verification** is the #1 missed check on Base

## Open decisions
- [ ] Build a runnable Anchor PoC for account confusion (Cashio pattern)
- [ ] Pick a live Base bounty target (Aerodrome, Moonwell, Morpho-on-Base) for dry-run
- [ ] Create semgrep rules for top Solana patterns (missing signer, account confusion)
- [ ] Research recent Solana exploits (Drift, Cetus) for case studies

## Next actions (backlog)
- [ ] Deep-dive case studies: Drift Protocol ($270M durable-nonce abuse), Cetus ($223M liquidity overflow)
- [ ] Mine Code4rena Solana reports → checklist items + semgrep rules
- [ ] Stand up Anchor PoC project under `poc-solana/`
- [ ] Live dry-run on Base target with slither + semgrep
- [ ] Add Solana detector ideas to `tools/` (cargo-geiger, soteria)

## Sources reviewed
- Helius: Hitchhiker's Guide to Solana Program Security
- Nomos: Anchor Framework Security Limits and Remaining Risks
- VultBase: Anchor Program Security
- Medium: Solana Security in the Anchor V2 Era
- AnchorScan: AnchorLang Security Best Practices 2026
- Chainlink: L2 Sequencer Uptime Feeds
- OP Stack Docs: Cross-Domain Overview
- Messari: State of the OP Stack Q1 2026
