# 2026-06-01 — Security tooling landscape (autonomous)

## What we did
- Surveyed existing security tooling and how it applies to web3 safety.
  Wrote `docs/methodology/security-tooling-landscape.md`.
- Rewrote README: removed the thesis/caveat, now leads with the **technical approach**
  (4 stages + hunt pipeline) and **brief tool summaries**.

## Key findings
- **Shannon** (KeygraphHQ) — autonomous web-app pentester: 5-phase multi-agent, parallel
  specialist agents per vuln class, **no-exploit-no-report**, Claude + Docker + Temporal.
  Clean architectural blueprint for an agentic smart-contract hunter; matches our flow.
- **forefy/.context** — Agent Skills (`SKILL.md`) for SC auditing (Solidity/Anchor/Vyper/
  Sui), installs to `.claude/skills/`, generates findings + PoCs + attacker story graphs.
  **Runs in our exact (Claude) environment — top adopt candidate.**
- **smartguard** — multi-agent (Analyzer→Skeptic→Exploiter→Generator→Runner), Slither +
  RAG (Pinecone) + `forge test`. Essentially our suite wired into agents; copy the
  **Skeptic** false-positive filter.
- **Heimdallr** (arXiv) — neuro-symbolic + Z3; *per paper* reproduced 17/20 post-Jun-2025
  exploits ($384M), 4 zero-days on $400M TVL, incl. Balancer V2 $128M precision-loss.
  **Validates SC07 (precision) is best attacked with symbolic verification (Halmos/Z3).**
- **heimdall-rs** — decompiles unverified bytecode → adopt into RECON.
- **Defensive layer:** Forta Attack Detector (+BlockSec/Nethermind), OZ Defender
  auto-pause, Tenderly simulation. Pattern: monitor → threshold → circuit-breaker.

## New questions (→ backlog)
- Package our suite as **Agent Skills** (`SKILL.md`) like forefy/.context?
- Benchmark suite+agent against **EVMBench / Heimdallr's 20-exploit set**?
- Build a **RAG corpus** from `docs/exploits/` + Solodit 370 + Code4rena reports?
- Add a **Halmos** PoC alongside the Foundry ERC-4626 case; compare coverage.
- Auto-detect whether a target has Forta/Defender auto-pause (factor into payout realism)?

## Next
- [ ] Trial-install forefy/.context skills; see how our checklists plug in as patterns.
- [ ] Add Halmos to `poc/` for the SC07 class.
- [ ] Continue deep-dives (Balancer V2 precision-loss is now well-motivated by Heimdallr).
