# Research Log — 2026-06-04

## Focus: Semgrep Rules + Target Scouting + Feed Scan

### Done

**1. Two new semgrep rules added** (`tools/semgrep/`):
- `governance-snapshot.yaml` — `governance-voting-power-no-snapshot` rule with 8 pattern-alternatives targeting governance functions that read live voting power (balanceOf, getVotes, totalRoots, totalSupply) at execution time rather than from snapshots. Maps to SC02-GOV-1 / Beanstalk $181M.
- `public-setter.yaml` — `public-setter-without-access-control` rule with 14 pattern-alternatives targeting public/external setter functions that modify access-control mappings without modifiers. Maps to SC02-AC / TrustedVolumes $6.7M.

**2. Checklist updates** (`checklists/master-checklist.md`):
- SC02-GOV-1: added semgrep rule reference
- SC02-AC: added semgrep rule reference

**3. Bug bounty target scouting** (`docs/research-plans/bounty-targets-2026-06.md`):
- 10 active programs scouted from Immunefi + HackenProof
- Tier 1 (>$1M): Uniswap v4 ($15.5M), LayerZero ($15M), Sky ($10M), Wormhole ($5M), Optimism ($2M), Lido ($2M), Kamino ($1.5M), Aave v3 ($1M)
- Tier 2 ($100K-$1M): 1inch ($500K), Marinade ($250K)
- Priority analysis: Kamino (Solana, $1.5M) and Aave v3 (Base, $1M) are best fits for our catalog

**4. Volo Protocol classification corrected** (`docs/exploits/2026-recent-exploits.md`):
- Changed from SC02 vault → X03 admin key based on GoPlus Security/ExVul/Bitslab confirmation that audited Move contracts were not flawed
- Not a code exploit — compromised privileged operator key, likely social engineering
- No case study warranted (same class as Wasabi Protocol, Drift Protocol)

### Web3isgoinggreat feed scan
- Feed last updated 2026-05-21, no new entries since last run
- All code exploits from the feed have been covered in existing case studies

### Semgrep rule count
- Before: 2 files, ~12 rules
- After: 4 files, ~14 rules (governance-snapshot, public-setter added)

### Vault backlog items completed this run
- [x] Add semgrep rules for governance real-time voting power reads
- [x] Add semgrep rule for public setter without access control modifier
- [x] Target scouting: active bug bounty programs on Immunefi/HackenProof

### Remaining backlog
- Create Foundry PoC for governance flash-loan attack pattern (BeanstalkGovernance.t.sol exists — verify and mark done)
- Create Foundry PoC for multi-hop swap slippage inflation pattern (RheaSlippage.t.sol exists — verify and mark done)
- Create Foundry PoC for MMR out-of-bounds leaf pattern (Hyperbridge) — VerusMerkleForgery.t.sol exists
- Add semgrep rule: mmr-unconsumed-leaves for missing post-loop checks
- Stand up Solana-specific PoC harness (Anchor test framework)
- Stand up Sui/Move-specific PoC harness
