---
name: aegis-audit
description: >-
  Use when auditing or reviewing a smart contract or live bounty target for
  vulnerabilities, evaluating a target against known DeFi exploits, hunting for bugs,
  triaging a bounty scope, or reproducing a suspected exploit — on EVM (Solidity),
  Solana (Anchor), or Sui/Aptos (Move) targets. Red-team vulnerability discovery that
  proves each finding with a runnable PoC. NOT for deploy/upgrade release-gating (use
  aegis-defender) or non-security code review.
version: 2.0.0
author: novaondesk
license: MIT
allowed-tools: Read Glob Grep Bash Write Edit AskUserQuestion Task TaskCreate TaskList TaskUpdate TodoRead TodoWrite
prerequisites:
  commands: [forge, slither, semgrep]
metadata:
  hermes:
    category: security
    tags: [security-audit, smart-contracts, defi, exploit-analysis, solidity, foundry, vulnerability-detection, web3]
    related_skills: [aegis-defender]
---

# Aegis — Exploit-Catalog Audit

Audit a target by **sweeping it against every exploit Aegis has studied**, then proving
the hits with PoCs — not by auditing from memory. The durable asset is
[`catalog/exploits.yaml`](../../catalog/exploits.yaml); this skill is the procedure that
runs it. Pair it with [`aegis-defender`](../aegis-defender/SKILL.md) to ship the fix.

> **Run from a checkout of the Aegis repo.** Reference files under `references/` resolve
> next to this SKILL.md; repo assets resolve from the repo root (`../../catalog/…`,
> `../../checklists/…`, `../../poc/`). A bare copy of just this folder won't find the
> catalog. `forge` drives EVM PoCs; `slither`/`semgrep` accelerate probes if installed
> (the sweep is reasoning-first and works without them).

## Essential principles (non-negotiable)

1. **Defensive / responsible-disclosure only.** In-scope bounty targets, public
   post-mortems, or your own deployments. The goal is to get bugs *fixed*. Never probe
   out-of-scope or live contracts you aren't authorized to test. *Why:* this is the line
   between security research and an attack.
2. **No finding without a runnable PoC.** A Foundry / `anchor test` / Move test that
   breaks the entry's stated `invariant`. An unproven match is a **hypothesis**, not a
   finding. *Why:* LLMs produce plausible-but-wrong vulns; the PoC is the truth oracle.
3. **Sweep, don't reminisce.** Evaluate the target against the *catalog*, not your
   training-data memory of "common bugs." *Why:* coverage you can prove ("checked all N")
   beats a vibe, and the catalog encodes signals memory skips.
4. **Cite primary sources** for any exploit/$ claim; verify before asserting.

## When to use
- Auditing/reviewing a contract or live bounty target for vulnerabilities.
- "Evaluate this target against all known exploits" / "what could go wrong here?"
- Triaging a bounty scope, or reproducing a suspected bug as a PoC.

## When NOT to use
- **Deploy/upgrade readiness, CI/CD, signer opsec** → use [`aegis-defender`](../aegis-defender/SKILL.md).
- **Generic non-security code review** → use a code-review skill; this hunts exploits.
- **Studying a single known incident** for its own sake → read `docs/exploits/<id>.md`
  (or the DeFiHackLabs fork-replay linked as `fork_poc`); no sweep needed.

## Workflow (numbered phases — do them in order)

### Phase 1 — RECON & SCOPE
**Entry:** you have the target source (or decompile unverified bytecode with heimdall-rs).
**Actions:**
1. Read all source. Map architecture, privileged roles, trust boundaries, external calls,
   value entry/exit points. Enumerate entry points (public/external fns, Anchor
   instructions, Move entry funs).
2. Classify: **chain** (evm / solana / sui-move / …) and **archetype(s)** — vault, AMM/CLMM,
   lending, perp, stablecoin-mint, bridge, oracle-consumer, dao-governance, anchor-program, …
3. Emit a **scope block** (≤30 lines):
   ```
   Target: <name>  Chain: <…>  Archetype(s): <…>
   Privileged roles: […]   Value in/out: […]   Key invariants (≤5): […]
   External deps / oracles: […]
   ```
4. **Select what to run** (scope-first — don't run everything blindly): filter the catalog
   to entries whose `chains` + `archetypes` could apply, and pick the REVIEW engines that
   fit (see `references/general-engines.md`). This bounds the work.
**Exit:** scope block written; candidate catalog entries + engines selected.

### Phase 2 — SWEEP (the heart of Aegis)
**Entry:** Phase 1 complete. Load [`catalog/exploits.yaml`](../../catalog/exploits.yaml).
**Actions:** for **every** candidate entry, evaluate `applies_when` against the source and
rank it. Make probes **scale**: combine each entry's `variant_queries` / `probes` into one
combined regex per pass and Grep the whole codebase once — never N files × M patterns
(see `references/sweep-rigor.md`). Use the entry's `root_cause` statement to judge true vs
false matches.
```
for entry in candidates:
    evaluate entry.applies_when against source
    grep entry.variant_queries (combined) → review every hit against entry.root_cause
    rank: HIGH (all preconditions hold) | MED (most hold) | LOW | N/A
```
Optionally accelerate with `slither --config-file ../../tools/slither/slither.config.json`
and `semgrep --config ../../tools/semgrep <target>`; map every hit back to a catalog id.
Most entries are `detection.static_flags: false` — scanners won't catch them; the
preconditions are how you find them.
**Exit:** a **coverage table** with one row per candidate entry, each with a verdict.
Nothing studied is silently skipped.

### Phase 3 — REVIEW (novel bugs the catalog doesn't list)
**Entry:** Phase 2 complete.
**Actions:** the catalog encodes *known* exploits; this phase finds *new* ones. Run the two
general engines from `references/general-engines.md`:
- **State-invariant inference** — infer sum / conservation / ratio / monotonic / sync
  relations between state vars, then find functions that break them.
- **Semantic-guard consistency** — a contract is its own spec: find functions missing a
  check (modifier / require / pause) that siblings consistently apply.
Then walk [`checklists/master-checklist.md`](../../checklists/master-checklist.md) for the
archetype; fall back to [`solodit-aggregated-checklist.md`](../../checklists/solodit-aggregated-checklist.md)
for breadth. Spend the most time on SC02 (logic), SC03 (oracle), SC07 (precision).
**Exit:** general-engine findings + uncovered-surface notes appended to the coverage table.

### Phase 4 — HYPOTHESIZE
**Entry:** ranked matches + engine findings exist.
**Actions:** for each HIGH/MED row, write one concrete sentence:
*"if <attacker does X> then <gains Y> because <invariant Z breaks>."* Use the entry's
`invariant` as the property to violate.
**Exit:** every HIGH/MED row has a falsifiable hypothesis.

### Phase 5 — PROVE (PoC or it didn't happen)
**Entry:** hypotheses exist.
**Actions:** write a PoC under `poc/`: `Vulnerable<X>.sol` + `Safe<X>.sol` +
`test/<X>.t.sol` with `test_*_isExploited` (attacker profits / invariant breaks) and
`test_*_resistsAttack` (the fix holds). Run `cd poc && forge test --match-contract <X> -vv`.
For a `coded` catalog entry, its `poc_cmd` is the worked template. Arithmetic/precision
(SC07): add a Halmos/Z3 symbolic check or fuzz with dust amounts.
**Exit:** the vulnerable test passes (exploit reproduced) **and** the safe test passes
(fix proven). A hypothesis without a passing PoC stays a hypothesis.

> **Fork-PROVE mode (real targets):** when auditing a *deployed* target rather than a
> pattern, prove against forked real state instead of a hand-built model — see
> [`../../sim/`](../../sim/) and [`references/fork-simulation.md`](references/fork-simulation.md).
> Fork the chain at a pinned block (`vm.createSelectFork`), deploy only your attacker, and
> drive the exploit against the live target + its real dependencies (oracles, pools, approvals).
> A finding is confirmed when the catalog entry's `invariant` breaks and the attacker profits
> on the fork. This is also how a catalog entry earns a real `fork_poc` (vs. a model PoC).

### Phase 6 — SCORE & REPORT
**Entry:** PoC-backed findings exist.
**Actions:** score each finding's confidence (`references/confidence-scoring.md`) and write
it in the structured format (`references/finding-format.md`): severity (Immunefi V2.2) +
confidence %, location, root cause, exploit steps, impact, **fix (lead with it)**, PoC.
Open with the coverage table so the reader sees what was checked.
**Verification (do not skip):** every reported finding has a file:line location, a passing
PoC command, and a concrete fix; no placeholder text remains; every catalog candidate has a
verdict in the coverage table.
**Exit:** report emitted; hand fixes to `aegis-defender` for release-gating.

## Scope-first engine selection

Run only what fits the archetype (bounds token use; see the tiering note in
`references/confidence-scoring.md`).

| Archetype | Catalog classes to prioritize | REVIEW engines |
|---|---|---|
| Vault / ERC-4626 | SC07 precision, SC02 | state-invariant (ratio), semantic-guard |
| AMM / CLMM / stableswap | SC07, SC03, SC08 reentrancy | state-invariant (ratio/conservation) |
| Lending / perp / cross-margin | SC03 oracle, SC02 | state-invariant (sync), semantic-guard |
| Stablecoin mint / bridge | SC05 validation, SC02 | semantic-guard, state-invariant (sum) |
| DAO governance | SC02, SC04 flash-loan | semantic-guard (snapshot vs realtime) |
| Anchor / Move program | SC05 account/CPI, SC07 | semantic-guard, entry-point review |

**Tiered output depth:** PoC only for Critical/High; Medium → root cause + ≤3-step exploit;
Low/Info → one line. If a dimension has no attack surface, write "N/A" and move on.

## Rationalizations to Reject

LLMs talk themselves out of real findings. Reject these:

| Rationalization | Why it's wrong |
|---|---|
| "Looks clean, skip the deep pass" | Surface cleanliness ≠ security. Every entry point gets evaluated. |
| "Well-known protocol / fork, it's safe" | Forks copy bugs; the original may be unaudited. Check *this* code+version. |
| "No matches, so it's secure" | Zero findings often means weak analysis, not safe code. Did you actually run the sweep? |
| "The match is probably a false positive" | Don't dismiss — check it against the entry's `root_cause`, then prove or disprove with a PoC. |
| "Admin is trusted, ignore it" | Model admin compromise and excessive powers; rugpull-by-design is a finding. |
| "Small rounding / dust, not worth it" | Precision leaks compound (see Balancer); dust is the *exploit*, not noise. |
| "Can't write a PoC, but I'm sure" | Then it isn't a finding yet. No PoC, no claim. |
| "The EVM-model PoC passed, so the Solana/Move target is vulnerable" | An EVM model proves the *class*, not the target. Label it illustrative; a native repro is what confirms it (see `references/finding-format.md`). |

## Reference index
| File | Use |
|---|---|
| [references/sweep-rigor.md](references/sweep-rigor.md) | Root-cause statements + abstraction ladder + scalable probing (the SWEEP discipline) |
| [references/general-engines.md](references/general-engines.md) | State-invariant inference + semantic-guard consistency (REVIEW phase) |
| [references/confidence-scoring.md](references/confidence-scoring.md) | Confidence formula, FP rates, tiering, Immunefi mapping |
| [references/finding-format.md](references/finding-format.md) | Coverage table + structured finding + report template |

Repo assets: [`catalog/exploits.yaml`](../../catalog/exploits.yaml) (schema:
[`catalog/README.md`](../../catalog/README.md)) · [`checklists/`](../../checklists/) ·
[`docs/exploits/`](../../docs/exploits/) · [`poc/`](../../poc/) · [`tools/`](../../tools/).

## Success criteria
- [ ] Scope block emitted; catalog filtered by chain + archetype.
- [ ] Coverage table: every candidate entry has a verdict (HIGH/MED/LOW/N/A).
- [ ] REVIEW engines run; novel-bug surface noted.
- [ ] Every reported finding has a **passing PoC** (vulnerable + safe) and a fix.
- [ ] Each finding scored (severity + confidence %); report leads with the fix.

## Closing the loop (every new pattern learned)
If the sweep teaches a new pattern or a target reveals a novel bug: write a
`docs/exploits/` case study, **add a `catalog/exploits.yaml` entry** with checkable
`applies_when` + a `root_cause` statement + `variant_queries`, sharpen a
`master-checklist.md` item, add a semgrep rule and/or invariant, append `research-log/`,
and code the PoC (`status: coded`). Commit as `novaondesk` (no AI trailer) and push. See
[`AGENTS.md`](../../AGENTS.md).
