---
name: smart-contract-bounty-review
description: >
  Review a smart contract for bug-bounty-grade vulnerabilities using the DeFi Bounty
  Suite's exploit-derived checklists and PoC workflow. Use when asked to audit/review a
  Solidity (or Anchor/Move) contract, hunt for vulnerabilities, triage a bounty target,
  or reproduce a suspected bug with a runnable PoC.
---

# Smart Contract Bounty Review

Packages the DeFi Bounty Suite into a loadable agent skill. Drives a contract review
from recon to a runnable PoC, using this repo's pattern library.

## When to use
- Auditing/reviewing a contract or a live bounty target for vulnerabilities.
- Triaging an address/codebase and ranking exploit hypotheses.
- Reproducing a suspected bug as a PoC.

## Hard rules (non-negotiable)
1. **Responsible disclosure only** — in-scope bounty targets, public post-mortems, or
   own deployments. Never probe out-of-scope/live contracts.
2. **No finding without a runnable PoC** — a Foundry (EVM) test that breaks an invariant.
   Unproven hypotheses are candidates, not findings.
3. **Cite primary sources** for any exploit/$ claim; verify before asserting.

## Workflow
```
1. RECON    Read all source; map architecture, roles, trust boundaries, external calls,
            value flows. For unverified on-chain code, decompile with heimdall-rs.
            Identify the protocol archetype (vault / AMM / lending / LSD / staking / bridge).
2. TRIAGE   Run automated first-pass:
              slither <target> --config-file tools/slither/slither.config.json
              semgrep --config tools/semgrep <target>
            Record which candidates map to which checklist IDs.
3. REVIEW   Walk checklists/master-checklist.md — the class checks AND the matching
            archetype playbook. For breadth, fall back to
            checklists/solodit-aggregated-checklist.md (370 items).
            Spend the most time on SC02 (logic), SC03 (oracle), SC07 (precision):
            tools can't read economic intent — you must.
4. HYPOTH.  For each suspicious item, state: "if <attacker does X> then <gains Y>
            because <invariant Z breaks>."
5. PROVE    Write a PoC under poc/: Vulnerable<X>.sol + (optional) Safe<X>.sol +
            test/<X>.t.sol asserting the attacker profits / the invariant breaks.
            Run: cd poc && forge test --match-contract <X> -vv
            For arithmetic/precision (SC07), also consider a symbolic check (Halmos/Z3).
6. REPORT   Severity per Immunefi V2.2 (impact × privilege × likelihood). Include root
            cause, the vulnerable code, the attack steps, the broken invariant, the PoC,
            and a remediation.
```

## Reference material in this repo
- `checklists/master-checklist.md` — curated, exploit-justified checks + archetype playbooks.
- `checklists/solodit-aggregated-checklist.md` — 370-item EVM backstop.
- `docs/vuln-classes/` — taxonomy (OWASP SC Top 10 2026 + off-chain X-classes).
- `docs/exploits/` — case studies; `_TEMPLATE.md` for new ones.
- `poc/` — runnable Foundry PoCs; `poc/test/InflationAttack.t.sol` is the worked example.
- `tools/` — slither config, semgrep rules, foundry invariant templates.
- `docs/methodology/security-tooling-landscape.md` — when to reach for which tool.

## Closing the loop
After any review, if you learned a new pattern: add/sharpen a `master-checklist.md`
item, add a semgrep rule and/or invariant, write a `docs/exploits/` case study, and
append `research-log/`. Commit as `novaondesk` (no AI trailer) and push. See `AGENTS.md`.

## Multi-chain note
This skill is EVM-mature. For Solana (Anchor) and Sui/Move, use the per-ecosystem
checklists once present (`checklists/solana-*.md`, `checklists/move-*.md`); the workflow
phases are the same but the bug classes and PoC harness differ (Anchor `anchor test`,
Move native tests).
