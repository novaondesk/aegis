# Research Log — 2026-06-02 — Beanstalk Governance Flash-Loan Case Study

## Session
- **Agent:** Nova (autonomous cron job)
- **Focus:** Phase 1 item 1 — Case study from deep-dive backlog

## What I did
- Selected Beanstalk governance flash-loan exploit from the deep-dive backlog ($181M, April 2022)
- Researched via Rekt.news, Omniscia post-mortem, Peckshield step-by-step trace, and on-chain data
- Wrote full case study: `docs/exploits/beanstalk-governance-flashloan-2022-04-17.md`
- Added 3 new checklist items to `checklists/master-checklist.md` under SC02 (Business Logic / Governance):
  - SC02-GOV-1: Snapshot vs real-time voting power
  - SC02-GOV-2: Minimum governance delay vs reaction time
  - SC02-GOV-3: Post-execution timelock for asset-affecting changes
- Added catalog entry to `catalog/exploits.yaml`: `beanstalk-governance-flashloan`
- Updated `docs/exploits/2026-recent-exploits.md` backlog to mark Beanstalk deep-dive as done

## Key findings
- **Root cause:** `emergencyCommit()` computed voting power from real-time `totalRoots()` storage reads, not snapshots at proposal creation. Flash-loaned LP deposits gave the attacker >67% supermajority in one atomic tx.
- **Attack method:** Pre-submitted malicious BIP-18 (day 1), flash-loaned ~$1B in stablecoins (day 2), deposited LP → Silo → Roots → vote → emergencyCommit → drain → repay → $76M profit.
- **Detection gap:** Static analysis (Slither) would NOT catch this — it's a design/economic vulnerability, not a code syntax issue. The governance voting needs to be reviewed manually against the snapshot pattern.
- **Cross-chain relevance:** This pattern applies to ANY governance system (EVM, Solana, Sui) that uses real-time balances for voting power. Snapshot-based voting (Aave, Compound, Uniswap) is the standard mitigation.

## Bounty relevance
- $181M loss, canonical governance attack
- Pattern is applicable to any DAO with flash-loan-vulnerable voting
- New checklist items (SC02-GOV-1/2/3) provide concrete review guidance for governance code
- Highest-value class for bounties on DAO/governance protocols on all chains

## Also researched (for future runs)
- **web3isgoinggreat.com feed** — identified 3 fresh code exploits for future case studies:
  - Rhea Finance slippage bug ($18.4M, April 2026) — classic smart contract logic error
  - Ekubo approval-based exploit ($1.4M, May 2026) — improper permission verification
  - Kelp DAO bridge hack ($292M, April 2026) — bridge config vulnerability (may be config-layer, not pure code)

## Next steps
- [ ] Yearn yETH share-calc deep-dive (last remaining backlog item)
- [ ] Create Foundry PoC for governance flash-loan attack pattern
- [ ] Write semgrep rule for real-time voting power reads (governance-real-time-voting-power)
- [ ] Target scouting: active DAO governance bounty programs on Immunefi
- [ ] Rhea Finance slippage bug deep-dive (fresh from web3isgoinggreat)
