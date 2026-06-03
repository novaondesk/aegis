---
name: aegis-defender
description: >-
  Use when protecting a smart contract — turning audit findings into proven fixes,
  hardening a protocol against known exploit classes, or release-gating a deploy/upgrade
  (CI/CD trust, storage-layout/upgrade safety, ownership handoff, multisig/signer opsec,
  config drift). The blue-team half of Aegis. Use after aegis-audit produces findings,
  or before shipping to mainnet. NOT for discovering new vulnerabilities (use aegis-audit).
version: 1.0.0
author: novaondesk
license: MIT
allowed-tools: Read Glob Grep Bash Write Edit AskUserQuestion Task TaskCreate TaskList TaskUpdate TodoRead TodoWrite
prerequisites:
  commands: [forge, slither]
metadata:
  hermes:
    category: security
    tags: [smart-contracts, defi, remediation, release-gate, blue-team, hardening, solidity, foundry]
    related_skills: [aegis-audit]
---

# Aegis — Defender (protect the target)

The blue-team half of Aegis. [`aegis-audit`](../aegis-audit/SKILL.md) finds the bug;
**aegis-defender proves the fix and gates the release.** Two modes, picked in Phase 1:

- **MITIGATE** — turn each audit finding into a minimal fix backed by a `Safe<X>` PoC that
  defeats the same exploit. (Red → blue handoff.)
- **RELEASE-GATE** — decide whether a repo is safe to deploy/upgrade: build integrity,
  upgrade safety, access control, signer opsec, config drift. (For your own deployments.)

> Run from a checkout of the Aegis repo. `references/` resolve next to this SKILL.md; repo
> assets resolve from the root (`../../poc/`, `../../catalog/…`). `forge` proves fixes.

## Essential principles (non-negotiable)

1. **A fix isn't real until a `Safe<X>` PoC defeats the exact exploit.** Re-run the
   finding's `test_*_isExploited` against the patched contract and show it now reverts /
   the invariant holds. *Why:* "looks fixed" ships re-exploitable code.
2. **Evidence first (release-gate).** Only assert what the repo *proves* — contracts,
   deploy scripts, CI workflows, configs, tests. Separate **Detection** (what the repo
   shows) from **Policy** (what should be enforced). *Why:* a gate built on assumptions
   passes unsafe releases.
3. **Restore the broken invariant, minimally.** Fix the root cause (the catalog entry's
   `invariant` / `root_cause`), not the symptom; don't add unrelated surface.
4. **Defense in depth, but ranked.** A correct fix first; circuit breakers / caps /
   monitoring as additional layers, not substitutes.

## When to use
- After an `aegis-audit` run, to remediate findings with proof.
- Hardening a protocol against a class of known exploits before/after launch.
- Gating a deploy or upgrade; reviewing deploy scripts; ownership/role handoff; CI hardening.

## When NOT to use
- **Discovering new vulnerabilities** → use [`aegis-audit`](../aegis-audit/SKILL.md).
- **Generic refactoring / features** unrelated to security → use a normal dev workflow.

## Workflow (numbered phases)

### Phase 1 — INTAKE & CLASSIFY
**Entry:** you have audit findings (MITIGATE) and/or a repo heading to deploy (RELEASE-GATE).
**Actions:**
1. Pick the mode(s). If findings exist → MITIGATE. If a deploy/upgrade is imminent →
   RELEASE-GATE. Both can run.
2. Classify the repo (evidence-backed): framework (Foundry/Hardhat), language
   (Solidity/Vyper/Move/…), **upgradeability** (immutable / proxy type), protocol type,
   deploy surface (script/CI/multisig), CI surface.
**Exit:** mode chosen; classification block emitted.

### Phase 2 — MITIGATE (per finding)
**Entry:** MITIGATE mode; a finding with a `Vulnerable<X>` + failing-invariant PoC exists.
**Actions:** for each finding, in severity order:
1. Identify the broken invariant (from the finding / catalog entry).
2. Derive the **minimal fix** that restores it — use the pattern map in
   `references/mitigation-patterns.md` (snapshot voting, virtual-offset, CEI + reentrancy
   lock, TWAP/oracle hardening, terminal-min + post-swap check, account/CPI anchoring,
   correct overflow boundary, caps + circuit breakers, …).
3. Implement it as `Safe<X>` in `poc/` (or patch the target).
4. **Prove it:** the finding's `test_*_isExploited` must now fail against the safe version,
   and `test_*_resistsAttack` must pass. `cd poc && forge test --match-contract <X> -vv`.
**Exit:** every finding has a `Safe<X>` whose test defeats the original exploit.

### Phase 3 — RELEASE-GATE
**Entry:** RELEASE-GATE mode; classification done.
**Actions:** run the evidence-backed checks in `references/release-gate-checklist.md`:
1. **Build integrity** — pinned deps/compiler, lockfile, reproducible build.
2. **Upgrade safety** — storage-layout compatibility, initializer protection, no
   self-destruct/`delegatecall` to mutable targets, upgrade authority.
3. **Access control & handoff** — owner/admin roles, two-step ownership, no leftover
   deployer powers, timelock on privileged actions.
4. **Signer / multisig opsec** — threshold, signer set, key custody evidence.
5. **Config drift** — deploy params vs intended (addresses, oracles, caps) match an
   address book; no hardcoded test values.
6. **Monitoring & pause** — pausability, circuit breakers, alerting hooks present.
**Exit:** each check has a Detection result + a verdict.

### Phase 4 — HARDEN (defense in depth)
**Entry:** Phases 2/3 produced fixes and/or gaps.
**Actions:** recommend additional layers tied to the catalog classes the target touches:
Foundry **invariant tests** for the restored invariants (`tools/foundry-invariants/`),
per-asset caps, oracle deviation/staleness bounds + TWAP, pausability, rate limits, and
monitoring. Rank each as fix / strongly-recommended / optional.
**Exit:** ranked hardening list, each mapped to a class id.

### Phase 5 — REPORT & VERIFY
**Entry:** fixes + gate results exist.
**Actions:** emit the report (`references/release-gate-checklist.md` has the template):
- **Remediation table:** finding → root cause → fix → **proven by `Safe<X>` ✓** → residual risk.
- **Release verdict:** `BLOCK` (unresolved Critical/High) · `PASS-WITH-CONDITIONS`
  (list them) · `PASS`, each line backed by evidence.
**Verification (do not skip):** every fix has a passing `resistsAttack` test; every gate
verdict cites a file/line of evidence; no Critical/High finding is marked resolved without
a proof.
**Exit:** report emitted.

## Rationalizations to Reject
| Rationalization | Why it's wrong |
|---|---|
| "The fix is obvious, skip the Safe PoC" | Unproven fixes ship re-exploitable. Re-run the exploit against the patch. |
| "It's audited, so it's safe to deploy" | Audits cover code, not deploy params, signer setup, or upgrade safety. Gate those. |
| "The upgrade is backward compatible" | Verify the *storage layout* — appended/reordered vars silently corrupt state. |
| "Admin can fix it live if needed" | Live-fix assumes an uncompromised admin and time to react; attackers are atomic. |
| "A pause/circuit breaker covers it" | A breaker is a backstop, not a fix. Restore the invariant first. |
| "Two-step ownership is overkill" | One-step transfer to a wrong/contract address is an unrecoverable bricking. |

## Reference index
| File | Use |
|---|---|
| [references/mitigation-patterns.md](references/mitigation-patterns.md) | Fix pattern per vuln class, mapped to catalog entries + their `Safe<X>` proofs |
| [references/release-gate-checklist.md](references/release-gate-checklist.md) | Evidence-backed deploy/upgrade/CI/signer checks + report template |

Repo assets: [`poc/`](../../poc/) (the `Safe<X>` proofs) · [`catalog/exploits.yaml`](../../catalog/exploits.yaml) ·
[`tools/foundry-invariants/`](../../tools/foundry-invariants/) · [`checklists/`](../../checklists/).

## Success criteria
- [ ] Every audit finding has a minimal fix **proven by a `Safe<X>` test** (exploit now fails).
- [ ] Release-gate: every check has a Detection result + evidence-backed verdict.
- [ ] Hardening list ranked (fix / recommended / optional), mapped to class ids.
- [ ] A clear release verdict: BLOCK / PASS-WITH-CONDITIONS / PASS.
