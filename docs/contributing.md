---
title: Contributing
nav_order: 9
---

# Contributing
{: .no_toc }

The repo is a compounding asset: every contribution should make the next target easier to audit —
ideally by adding or sharpening a catalog detector. Read
[`AGENTS.md`](https://github.com/novaondesk/aegis/blob/main/AGENTS.md) first.
{: .fs-5 .fw-300 }

1. TOC
{:toc}

## Hard rules

1. **Responsible disclosure only.** In-scope bounty targets, public post-mortems, or your own deploys — to get bugs fixed.
2. **No claimed finding without a runnable PoC.** Foundry (EVM) or the chain's native harness; the PoC must break the stated invariant.
3. **Cite primary sources.** Web reporting is a lead, not a fact — verify $ figures and root causes against the post-mortem + on-chain trace.
4. **Don't break the build.** `cd poc && forge test` must pass.

## The contribution loop

Every new exploit studied updates **four places** — this is the loop:

1. A **case study** in [`docs/exploits/`](https://github.com/novaondesk/aegis/tree/main/docs/exploits).
2. A **detector entry** in [`catalog/exploits.yaml`](https://github.com/novaondesk/aegis/blob/main/catalog/exploits.yaml) — with checkable `applies_when` preconditions, a `root_cause` line, and `variant_queries`.
3. A sharpened item in `checklists/master-checklist.md`.
4. A detection artifact — a semgrep rule and/or invariant template — plus a runnable PoC (`Vulnerable<X>` + `Safe<X>` + test).

Then append a dated note to [`research-log/`](https://github.com/novaondesk/aegis/tree/main/research-log).

## Adding a PoC

1. `poc/src/<area>/<X>.sol` — minimal `Vulnerable<X>` + `Safe<X>`. Comment the bug.
2. `poc/test/<X>.t.sol` — `test_*_isExploited` (attack profits / invariant breaks) **and** `test_*_resistsAttack` (the fix holds).
3. Flip the catalog entry to `status: coded` with `poc` + `poc_cmd`.
4. For a real deployed target, add a fork replay under [`sim/`](https://github.com/novaondesk/aegis/tree/main/sim) and point the entry's `fork_poc` at it.

## Where things live

| Path | What |
|---|---|
| `catalog/` | the exploit catalog (sweep source) |
| `skills/` | `aegis-audit` (red) · `aegis-defender` (blue) |
| `docs/exploits/` | one case study per incident/class |
| `poc/` | runnable model PoCs |
| `sim/` | real-incident fork replays |
| `ethernaut/` | the wargame validation harness |
| `checklists/`, `tools/` | exploit-justified checks; slither/semgrep/invariants |
