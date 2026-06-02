---
name: aegis-audit
description: >
  Audit a smart contract against Aegis's catalog of studied real-world exploits to
  find vulnerabilities, then prove each one with a runnable PoC. Use when asked to
  audit/review a Solidity (or Anchor/Move) contract or protocol, evaluate a target
  against known exploits, hunt for vulnerabilities, triage a bounty target, or
  reproduce a suspected bug. Loads catalog/exploits.yaml and sweeps the target
  against every known exploit before going deep.
version: 1.0.0
author: novaondesk
license: MIT
prerequisites:
  commands: [forge, slither, semgrep]
metadata:
  hermes:
    category: security
    tags: [security-audit, smart-contracts, defi, exploit-analysis, solidity, foundry, vulnerability-detection, web3]
    related_skills: []
---

> **Reference files resolve relative to the repo root** (`../../catalog/…`,
> `../../checklists/…`, `../../poc/`). Run this skill from a checkout of the Aegis
> repo, or register it in place (Hermes: add `<repo>/skills` to `skills.external_dirs`)
> — a bare copy of just this directory will not find the catalog. Tools: `forge`
> drives EVM PoCs; `slither`/`semgrep` accelerate TRIAGE if installed (the sweep is
> reasoning-first and still works without them, EVM PoCs aside).

# Aegis — Exploit-Catalog Audit

Packages Aegis into a loadable agent skill. The core idea: don't audit from memory —
**sweep the target against every exploit Aegis has studied**, then prove the hits.
The durable asset is [`catalog/exploits.yaml`](../../catalog/exploits.yaml); this skill
is the procedure that runs it.

## When to use
- Auditing/reviewing a contract or live bounty target for vulnerabilities.
- "Evaluate this target against all known exploits" / "what could go wrong here?"
- Reproducing a suspected bug as a PoC.

## Hard rules (non-negotiable)
1. **Defensive / responsible-disclosure only** — in-scope bounty targets, public
   post-mortems, or own deployments. The goal is to find bugs so they get *fixed*.
   Never probe out-of-scope or live contracts you aren't authorized to test.
2. **No finding without a runnable PoC** — a Foundry (EVM) / `anchor test` / Move test
   that breaks the entry's stated invariant. Unproven matches are *hypotheses*, not findings.
3. **Cite primary sources** for any exploit/$ claim; verify before asserting.

## Workflow

### 1. RECON — understand the target
Read all source. Map architecture, roles, trust boundaries, external calls, value
flows. For unverified on-chain code, decompile with heimdall-rs. Pin down:
- **chain** (evm / solana / sui-move / …) and **archetype(s)** — vault, AMM/CLMM,
  lending, perp, stablecoin-mint, bridge, oracle-consumer, Anchor-program, etc.

### 2. SWEEP — the catalog pass (this is the heart of Aegis)
Load [`catalog/exploits.yaml`](../../catalog/exploits.yaml). Filter to entries whose
`chains` and `archetypes` could apply to the target, then for **every** such entry:
```
for entry in catalog (matching chain + archetype):
    evaluate entry.applies_when against the target's source
    run entry.probes (grep / semgrep / manual checks)
    rank: HIGH (all preconditions hold) | MED (most hold) | LOW/NA
```
Produce a **coverage table** — one row per catalog entry — so it's explicit which
known exploits were checked and what the verdict was. Nothing studied gets skipped.

> Run the automated probes to accelerate the sweep, not replace it:
> `slither <target> --config-file tools/slither/slither.config.json`
> `semgrep --config tools/semgrep <target>`
> Map each hit back to the catalog entry / checklist id it supports. Most catalog
> entries have `detection.static_flags: false` — scanners won't catch them; the
> preconditions are how you find them.

### 3. REVIEW — fill the gaps the catalog doesn't cover
The catalog encodes *known* exploits. For novel logic, walk
[`checklists/master-checklist.md`](../../checklists/master-checklist.md) (class checks +
the matching archetype playbook); fall back to
[`checklists/solodit-aggregated-checklist.md`](../../checklists/solodit-aggregated-checklist.md)
(370 items) for breadth. Spend the most time on SC02 (logic), SC03 (oracle), SC07
(precision) — tools can't read economic intent.

### 4. HYPOTHESIZE — make each match concrete
For each HIGH/MED row: *"if <attacker does X> then <gains Y> because <invariant Z
breaks>."* Use the entry's `invariant` field as the property to violate.

### 5. PROVE — PoC or it didn't happen
Write a PoC under `poc/`: `Vulnerable<X>.sol` + (optional) `Safe<X>.sol` +
`test/<X>.t.sol` asserting the attacker profits / the invariant breaks.
`cd poc && forge test --match-contract <X> -vv`. For coded catalog entries, the
existing PoC (`entry.poc_cmd`) is the worked template. Arithmetic/precision (SC07):
add a symbolic check (Halmos/Z3) or fuzz with dust amounts.

### 6. REPORT — severity + remediation
Severity per Immunefi V2.2 (impact × privilege × likelihood). Include root cause, the
vulnerable code, attack steps, the broken invariant, the PoC, and a fix. Lead with the
fix — the point is to make the target safer.

## Output: a sweep report
```
Target: <name> (<chain>, archetype: <…>)
Catalog coverage: N/N entries evaluated
┌─────────────────────────────┬────────┬─────────────────────────────────────┐
│ exploit                     │ verdict│ note                                │
├─────────────────────────────┼────────┼─────────────────────────────────────┤
│ erc4626-inflation           │ HIGH   │ totalAssets() reads balanceOf(this) │
│ read-only-reentrancy        │ N/A    │ no pool-view used as oracle         │
│ …                           │ …      │ …                                   │
└─────────────────────────────┴────────┴─────────────────────────────────────┘
Findings (PoC-backed): …
```

## Reference material in this repo
- [`catalog/exploits.yaml`](../../catalog/exploits.yaml) — the exploit catalog (sweep source). Schema: [`catalog/README.md`](../../catalog/README.md).
- [`checklists/master-checklist.md`](../../checklists/master-checklist.md) — exploit-justified checks + archetype playbooks.
- [`docs/vuln-classes/`](../../docs/vuln-classes/) — taxonomy (OWASP SC Top 10 2026 + X-classes).
- [`docs/exploits/`](../../docs/exploits/) — the deep-dive case studies each catalog entry links to.
- [`poc/`](../../poc/) — runnable PoCs; `poc/test/InflationAttack.t.sol` is the worked example.
- [`tools/`](../../tools/) — slither config, semgrep rules, foundry invariant templates.

## Closing the loop
If the sweep teaches you a new pattern (or a target reveals a novel bug): write a
`docs/exploits/` case study, **add a `catalog/exploits.yaml` entry** with checkable
`applies_when` preconditions, sharpen a `master-checklist.md` item, add a semgrep rule
and/or invariant, and append `research-log/`. Commit as `novaondesk` (no AI trailer)
and push. See [`AGENTS.md`](../../AGENTS.md).

## Multi-chain note
EVM is most mature (coded PoCs). Solana (Anchor) and Sui/Move entries are `studied`
(catalog + doc, PoC not yet ported) — the sweep still applies; the PoC harness differs
(`anchor test`, Move native tests). Per-ecosystem checklists:
`checklists/solana-anchor-checklist.md` (and `move-*` as they land).
