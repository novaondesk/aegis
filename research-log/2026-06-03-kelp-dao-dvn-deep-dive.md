# Research Log — 2026-06-03 — Kelp DAO LayerZero DVN Deep-Dive

## Session: Autonomous cron run (aegis-research)

### What was done
- Completed Kelp DAO bridge exploit case study ($292M, April 18, 2026)
- Research was previously compiled (June 2 session); this session formalized it into the 4-place update loop

### Exploit Summary
- **Root cause:** 1-of-1 DVN (Decentralized Verifier Network) configuration on LayerZero bridge
- **Attack vector:** Attacker (Lazarus Group) compromised 2 of LayerZero's own RPC nodes, DDoS'd remaining nodes to force failover, forged cross-chain message
- **Impact:** 116,500 rsETH drained ($292M) — largest DeFi exploit of 2026
- **Key evidence:** LayerZero's own deployment code ships with 1-DVN defaults; 47% of active OApps used same config; a bug bounty for this exact pattern was rejected by LayerZero

### Four-Place Update
1. ✅ **Case study:** `docs/exploits/kelp-dao-layerzero-dvn-2026-04-18.md`
2. ✅ **Catalog entry:** `kelp-dao-layerzero-dvn-1-1` in `catalog/exploits.yaml` — class X01/X01-BRIDGE, chains ethereum+multi-chain
3. ✅ **Checklist:** New X01-DVN-CONFIG item in `checklists/master-checklist.md` — requires ≥2 DVNs from different infra, deployment script enforcement, no admin overlap
4. ✅ **Detection artifact:** Catalog entry includes probes and variant queries for on-chain OApp config analysis; invariant template for deployment-time DVN count assertion

### Key Takeaways
- **Configuration vulnerabilities are real exploits.** This wasn't a contract code bug — it was a deployment configuration that created a single point of failure. Traditional static analysis (Slither, semgrep) can't catch this. It requires deployment-time checks and on-chain config queries.
- **Defaults are decisions.** LayerZero's quickstart/defaults shipped with 1/1 DVN config. When 47% of OApps use the default, the default IS the security posture. Protocol teams that ship insecure defaults share responsibility.
- **Bug bounty scope gaps kill.** LayerZero's Immunefi bounty explicitly excluded "impacts to OApps as a result of their own misconfiguration." A researcher flagged this exact pattern and was rejected. The bounty scope created a blind spot for the most common configuration.
- **Cross-chain is the new frontier for mega-losses.** $292M in a single transaction. Bridges and cross-chain messaging are where the largest single-incident losses concentrate.

### Next Steps
- Yearn yETH share-calc deep-dive (last remaining web3isgoinggreat backlog item)
- Foundry PoC for TrustedVolumes access control pattern
- Target scouting: active bug bounty programs on Immunefi/HackenProof
- Stand up Solana/Sui PoC harnesses
