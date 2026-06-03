---
title: How it works
nav_order: 3
---

# How it works
{: .no_toc }

Aegis is a **catalog-driven audit loop**, shipped as two agent skills. The point is repeatability:
"we checked all N known exploits against this target" is a coverage claim, not a vibe.
{: .fs-5 .fw-300 }

1. TOC
{:toc}

## The audit loop (target → finding → fix)

```
1. RECON & SCOPE   pull source (or decompile via heimdall-rs); pin chain + archetype;
                   map roles, trust boundaries, value flows
2. SWEEP           evaluate the target against EVERY catalog entry whose archetype fits.
                   Each entry's applies_when + root_cause + variant_queries are checked
                   against the code → a coverage table (HIGH/MED/LOW/N-A). Nothing studied
                   is skipped.
3. REVIEW          general engines (state-invariant inference + semantic-guard consistency)
                   + exploit-derived checklists catch novel bugs the catalog doesn't list
4. PROVE           a Foundry/Anchor/Move PoC that breaks the entry's invariant (vulnerable +
                   safe). For a deployed target, prove on a fork of real state (see sim/).
5. SCORE & REPORT  severity (Immunefi V2.2) + confidence — lead with the fix
6. PROTECT         aegis-defender turns each finding into a fix proven by a Safe<X> PoC and
                   release-gates the deploy/upgrade
```

## The sweep (the heart of Aegis)

For every catalog entry whose `archetypes`/`chains` fit the target, the sweep scores the entry's
[`applies_when`](the-catalog) preconditions against the target's source. The more that hold, the
higher the hypothesis ranks. The entry's `root_cause` line is the true/false-positive judge: a match
only counts if the *unconstrained thing → sensitive op → missing protection* chain is actually
present. `variant_queries` give the grep/semgrep family to hunt the bug across the codebase.

A matched entry is a **hypothesis** — not a finding. It becomes a finding only when a PoC proves it.

## Prove: model vs. fork

- **Model PoC** ([`poc/`](https://github.com/novaondesk/aegis/tree/main/poc)) — a minimal,
  chain-agnostic `Vulnerable<X>` + `Safe<X>` + test. Teaches the detector and proves the fix in the
  abstract. See **[PoCs](pocs)**.
- **Fork PoC** ([`sim/`](https://github.com/novaondesk/aegis/tree/main/sim)) — fork the chain at a
  pinned block and exploit the **real deployed target** + its live dependencies; only the attacker is
  deployed. See **[Fork-simulation](fork-simulation)**.

## The two skills

| Skill | Team | Does |
|---|---|---|
| [`aegis-audit`](https://github.com/novaondesk/aegis/tree/main/skills/aegis-audit) | 🔴 red | RECON → SWEEP → engines → PoC → scored report |
| [`aegis-defender`](https://github.com/novaondesk/aegis/tree/main/skills/aegis-defender) | 🔵 blue | turns findings into fixes proven by a `Safe<X>` PoC + deploy/upgrade release-gate |

> There is no autopilot. Tools narrow the haystack; humans/agents find economic & logic bugs. If you
> "find a bug," it is not real until a runnable PoC breaks an invariant.
