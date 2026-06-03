# Prior Art — what exists, and what Aegis should steal

Reviewed by cloning and reading the actual source (2026-06-02). The goal: make Aegis the
best *catalog-driven audit + protect* skill, adopting better approaches wherever they
beat ours. This is an honest map, not a sales pitch.

## The comparables

| Project | What it is | Size / maturity | Overlap with Aegis |
|---|---|---|---|
| **DeFiHackLabs** (SunWeb3Sec) | Foundry **mainnet-fork replays** of real hacks, one per incident, indexed by date | **691 incidents / 729 PoCs**, `add_new_entry.py`, academy, sig DB | The PoC corpus — but forensic replays, not detectors |
| **QuillShield skills** (QuillAudits) | 11 Claude **plugin-skills**, one per vuln class + a BSA orchestrator + a blue-team `defender` | Mature skill design; confidence scoring; marketplace.json | The agent-skill + reasoning layer |
| **Trail of Bits skills** | ~40 security skills incl. native per-chain scanners, `variant-analysis`, `audit-context-building`, meta `designing-workflow-skills` | Reference-grade skill engineering | Skill rigor + native non-EVM coverage |
| **Almanax Web3 Security Atlas** | Open dataset of source + vuln data for AI tooling/benchmarks | Dataset, not a sweep | The "structured knowledge for AI" framing |
| **Solodit / OWASP SCSVS / SC Top 10** | Checklists & verification standards | Industry standard | Already our backstop |
| **rekt / De.Fi / SlowMist** | Incident databases (narrative) | Large | Our *sources*, not competitors |

## Per-project verdict

### DeFiHackLabs — the PoC giant we should *not* try to out-volume
- **Their approach:** each PoC is a `forge` test that `vm.createSelectFork`s the real chain
  at the attack block and replays the exploit against the **real deployed addresses**.
  Organized `src/test/YYYY-MM/<Incident>_exp.sol`. Automated intake (`add_new_entry.py`).
- **Where it beats us:** breadth (60×), realism (real bytecode, real liquidity), and a
  contribution pipeline. If you want to study an incident, theirs is the reference.
- **Where Aegis is better:** every Aegis PoC ships a **paired `Safe<X>` that proves the
  fix** — DeFiHackLabs only reproduces the attack. Aegis entries are **detectors with
  checkable `applies_when` preconditions**, not just a replay. Aegis is reasoning-first
  (find the bug in a *new* target), DeFiHackLabs is forensic (re-run a *known* one).
- **Adopt:** (1) link the matching DeFiHackLabs replay from each catalog entry as
  `fork_poc` — free realism backing for our minimal model. (2) Their date-indexed naming
  + an `add_new_entry` helper. (3) For *EVM* incidents we haven't modeled, a fork-replay
  is a faster path to `coded` than a hand-built model.
- **Reject:** chasing their count, and fork-replays as the *primary* artifact — a replay
  doesn't generalize to a new target the way a precondition + minimal model does.

### QuillShield — the closest skill competitor; steal its reasoning machinery
- **Their approach:** decompose audit into **per-class skills** (oracle/flashloan,
  reentrancy, proxy, signature-replay, arithmetic, DoS, external-call, plus two semantic
  engines), orchestrated by **Behavioral State Analysis (BSA)**: Phase 1 behavioral
  decomposition → Phase 2 multi-dimensional threat engines (run only the relevant ones)
  → Phase 3 adversarial PoC → Phase 4 **confidence scoring**.
- **Standout ideas worth copying wholesale:**
  - **Confidence scoring:** `Confidence = (Evidence × Feasibility × Impact) / FP_Rate`,
    with scored tables and "report ≥10%, never suppress Impact ≥4." Turns a vibe into a
    triage number. Aegis has *no* scoring today.
  - **Scope-first / token budget:** classify the contract, then run ONLY relevant engines;
    tiered output depth (PoC for Crit/High only, one-line for Low). Directly fixes the
    Cartesian-blowup risk in our "evaluate **every** entry" sweep on a big target.
  - **State-invariant inference** (sum / conservation / ratio / monotonic / sync) and the
    **semantic-guard "a contract is its own specification"** check — both are *general*
    detectors that complement our *specific* catalog, catching novel bugs the catalog
    doesn't list.
  - **`defender` skill** — a blue-team **release-gate** (deploy/upgrade/CI/signer opsec).
    This is the "protect them" half we under-serve.
  - **"Rationalizations to Reject"** in every skill — explicitly lists the shortcuts an
    LLM uses to talk itself out of a finding.
- **Where Aegis is better:** our catalog is a curated, sourced, PoC-backed corpus with
  real `$` and primary sources; QuillShield's "case-studies.md" are lighter. Our sweep
  yields an explicit **coverage claim** ("checked all N"); BSA doesn't.
- **Adopt:** confidence scoring, scope-first engine selection, the structured finding
  format, the two general engines (as a REVIEW-phase complement, not a replacement for the
  catalog), the defender release-gate, and "Rationalizations to Reject."

### Trail of Bits — reference-grade skill engineering + native non-EVM
- **`variant-analysis`** is *exactly* the rigor our SWEEP lacks: a **root-cause statement**
  ("this exists because [UNTRUSTED DATA] reaches [DANGEROUS OP] without [PROTECTION]"),
  then an **abstraction ladder** (Level 0 exact match → generalize ONE element at a time →
  stop at ~50% FP), with CodeQL/Semgrep templates. Our catalog `probes` are ad-hoc greps;
  this makes each entry a disciplined, FP-bounded variant hunt.
- **`designing-workflow-skills`** (meta) gives the rules our `aegis-audit` SKILL.md
  violates today (see gap list below): description = *triggers only*, numbered phases with
  entry/exit, progressive disclosure (<500 lines, `references/` one hop), least-privilege
  `allowed-tools`, scalable tool patterns (combine N×M greps into one regex), and a
  "Rationalizations to Reject" requirement for audit skills.
- **Native per-chain scanners** (Solana/Cairo/Cosmos/Move, each with a
  `VULNERABILITY_PATTERNS.md`) and **`entry-point-analyzer`** (per-language entrypoint
  enumeration) — relevant because we *EVM-modeled* the Solana/Move incidents. ToB shows
  what a native pattern doc looks like.
- **Adopt:** the variant-analysis discipline into the catalog schema + sweep; the skill
  structure rules; their entry-point enumeration approach for RECON; their native pattern
  docs as a template if we ever port the EVM-models to Anchor/Move.

### Almanax Atlas / Solodit / SCSVS / incident DBs
- Atlas = a dataset for training/benchmarking, not a sweep — useful as a *source* to mine
  more catalog entries, not a competitor. Solodit/SCSVS we already consume. Incident DBs
  (rekt/De.Fi/SlowMist) are lead sources.

## Aegis's defensible niche (after all this)
Nobody combines all four: **machine-readable detector w/ checkable preconditions → paired
vulnerable+safe runnable PoC → checklist item → run as a coverage sweep by an agent
skill.** DeFiHackLabs has PoCs but no detectors/sweep; QuillShield has the skill+scoring
but no PoC-backed catalog; ToB has the rigor but no DeFi-exploit catalog; Atlas has the
data but no sweep. Keep that core. Don't become QuillShield-with-fewer-skills; become the
catalog sweep done with QuillShield's scoring and ToB's variant rigor — plus a real
protect/defender half.

## Concrete gaps in our current `aegis-audit` skill (vs ToB skill rules)
1. **Description summarizes the workflow** ("Loads catalog/exploits.yaml and sweeps…") →
   AP-20: should be triggering conditions only.
2. **No `allowed-tools`**, no **When NOT to Use**, no **Rationalizations to Reject**
   (AP-16 — the #1 cause of missed findings).
3. **No confidence scoring / triage math**; severity is asserted, not scored.
4. **No scope-first bound** — "evaluate **every** entry" risks Cartesian blowup on large
   targets (AP-18). Need: classify → filter → combined-regex probes → tiered depth.
5. **Phases lack explicit entry/exit criteria and a verification step** (AP-6/7/8).
6. **Stale content:** says Solana/Move entries are `studied` — they're all `coded` now.
7. **Protect side is thin** — we have `Safe<X>` PoCs but no release-gate / mitigation pass.
8. **No progressive disclosure** — everything inline; no `references/`.

## Recommended changes (priority order)

> **Status (2026-06-02):** items 1–6 implemented — `aegis-audit` rewritten to ToB
> structure with confidence scoring + general engines + `references/`; catalog gained
> `root_cause` / `variant_queries` / `fork_poc` (all 10 backfilled); `aegis-defender`
> added. Item 7 (native Anchor/Move ports) remains future work.

1. **Rewrite `aegis-audit/SKILL.md`** to ToB structure: trigger-only description,
   `allowed-tools`, numbered phases w/ entry/exit + verification, Rationalizations,
   scope-first engine selection, structured finding format, confidence scoring. Fix stale
   text. Split detail into `references/`.
2. **Add confidence scoring + finding format** (QuillShield BSA) as the report standard.
3. **Sharpen the catalog schema:** add `root_cause` (the variant-analysis statement) and
   `variant_queries` (abstraction-ladder grep/semgrep) per entry; back-fill the 10.
4. **Add a `defender` / protect pass** (release-gate + "every finding ships a fix and a
   `Safe<X>` proving it") — the "protect them" half.
5. **Add two general REVIEW engines** (state-invariant inference + semantic-guard
   consistency) to catch what the catalog doesn't list.
6. **Cross-link DeFiHackLabs** fork-replays from EVM catalog entries as `fork_poc`.
7. (Later) Native Anchor/Move ports of the EVM-modeled entries, using ToB's native
   pattern docs as the template.
