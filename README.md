# DeFi Bounty Suite

A research project to study real-world DeFi exploits, distill them into reusable
vulnerability patterns, and build a **semi-automated triage suite** for reviewing
smart contracts on-chain — with the goal of finding (and responsibly disclosing)
bugs through bug-bounty programs (Immunefi, Sherlock, etc.).

## Technical approach

The suite layers four review stages over a curated, exploit-derived pattern library:

1. **Static analysis** — Slither + custom semgrep rules flag candidate patterns.
2. **Pattern checklist** — exploit-justified checks (OWASP SC Top 10 2026 + archetype
   playbooks) walked against the code.
3. **Dynamic verification** — Foundry/Echidna invariant tests + symbolic (Halmos/Z3)
   for the precision/arithmetic class.
4. **PoC** — every finding is reproduced as a runnable exploit before it counts.

### Hunt pipeline (target → finding)

```
1. SELECT   pick an in-scope bounty target (scope, payout, complexity)
2. RECON    pull verified source (or decompile via heimdall-rs), map trust boundaries
3. TRIAGE   run the automated suite (slither + semgrep)
4. REVIEW   walk the exploit-derived checklist + archetype playbooks
5. HYPOTH.  form a concrete "if X then attacker gains Y" hypothesis
6. PROVE    write a Foundry/Echidna PoC that breaks an invariant
7. REPORT   write up with severity (Immunefi V2.2) + working PoC
```

## Tools

Brief summaries of the tooling the suite uses and integrates. Full landscape +
integration notes: [`docs/methodology/security-tooling-landscape.md`](docs/methodology/security-tooling-landscape.md).

**Static analysis**
- **Slither** — industry-standard Solidity static analyzer (80+ detectors, AST-based).
  Config in `tools/slither/`. First-pass triage.
- **semgrep** — pattern-matching over source; `tools/semgrep/` holds custom rules, one
  per extracted exploit pattern (e.g. `balanceOf`-accounting, unchecked `ecrecover`).
- **Mythril / Aderyn** — symbolic and Rust-based static analyzers as deeper alternates.

**Dynamic & symbolic**
- **Foundry (`forge`)** — primary test/PoC framework; built-in fuzzing + invariant
  testing. All PoCs live in `poc/`.
- **Echidna / Medusa** — property-based fuzzers; define an invariant, hunt inputs that
  break it.
- **Halmos / Certora** — symbolic/formal verification; strongest on the arithmetic and
  precision class (SC07).

**Recon**
- **heimdall-rs** — EVM bytecode toolkit; decompiles and extracts info from *unverified*
  contracts, turning a black-box address into reviewable pseudo-source.

**AI audit agents (reference / integration candidates)**
- **forefy/.context** — Agent Skills (`SKILL.md`) for SC auditing across Solidity,
  Anchor, Vyper, Sui; installs to `.claude/skills/`. Generates findings, PoCs, attacker
  story-flow graphs. Directly usable in our Claude-based setup.
- **smartguard** — multi-agent auditor (Analyzer→Skeptic→Exploiter→Generator→Runner)
  combining Slither, a RAG vuln corpus, and `forge test` for PoC execution.
- **Shannon** — autonomous web-app/API pentester; architectural blueprint for an
  agentic, multi-phase, "no-exploit-no-report" hunter.

**Defensive / runtime (target-selection context)**
- **Forta**, **OpenZeppelin Defender**, **Tenderly** — on-chain monitoring, attack
  detection, transaction simulation, and automated circuit-breaker/pause response.

## Repo layout

| Path | What lives here |
|---|---|
| `docs/exploits/` | Case studies of real exploits — one file per incident |
| `docs/vuln-classes/` | The vulnerability taxonomy (mapped to OWASP SC Top 10 2026) |
| `docs/methodology/` | Industry practices, the tooling stack, the hunting workflow |
| `checklists/` | The **suite** — actionable per-class review checklists |
| `tools/slither/` | Slither configs / custom detector notes |
| `tools/semgrep/` | Custom semgrep rules for Solidity patterns |
| `tools/foundry-invariants/` | Reusable invariant-test templates |
| `targets/` | Notes on specific in-scope bounty targets (gitignored if sensitive) |
| `research-log/` | Dated log of what we looked at and what we found |

## Contributing (agents & humans)

Read **[`AGENTS.md`](AGENTS.md)** first — it's the contract for how Nova and other
agents contribute so the work compounds. The core loop: research → reproduce with a
runnable PoC → distill a case study → encode a checklist item + detector → log.

Active research day-plans live in [`docs/research-plans/`](docs/research-plans/)
(current: Nova on **Solana + Base**).

## Status

v0.2 — research scaffold + first runnable deep-dive.
- **Pattern library:** OWASP SC Top 10 (2026) taxonomy; 370-item Solodit EVM backstop;
  exploit-justified front-line checklist with archetype playbooks.
- **First coded deep-dive:** ERC-4626 share-inflation — vulnerable + safe contract + a
  passing exploit PoC (`poc/`, see `docs/exploits/erc4626-inflation-attack.md`).
- **Next:** Solana (Anchor) + Base checklists & PoCs per the day-plan; deep-dives for
  Cetus/Balancer/Yearn with real source.

See `research-log/` for the running log.

## Ground rules

- **Responsible disclosure only.** We hunt *in-scope* targets on bounty platforms,
  or our own deployments. No touching out-of-scope contracts, no live exploitation.
- Every claimed finding needs a **reproducible PoC** before it counts.
- We document *why* each pattern matters with a real loss attached — no theory-only
  entries.
