# DeFi Bounty Suite

A research project to study real-world DeFi exploits, distill them into reusable
vulnerability patterns, and build a **semi-automated triage suite** for reviewing
smart contracts on-chain — with the goal of finding (and responsibly disclosing)
bugs through bug-bounty programs (Immunefi, Sherlock, etc.).

## The thesis (and the honest caveat)

There is **no** "press a button, get a bug" tool. If there were, the bounty
programs would not be paying out $110M+. The high-value bugs are **business-logic
and economic** flaws that require understanding what the protocol is *supposed* to
do — and automated tools cannot read intent.

What *is* real, and what this repo builds toward:

> **Automated first-pass** (static analysis + custom pattern rules) to narrow the
> haystack → applied on top of a **curated, exploit-derived checklist** → confirmed
> with **invariant-testing harnesses** → finished with **human judgment**.

The durable asset here is **the pattern library** we build from studying real
exploits. The tooling is just a force-multiplier on a trained eye.

## How a hunt actually flows (target → finding)

```
1. SELECT   pick a live bounty target (scope, payout, complexity)
2. RECON    pull verified source, map architecture, identify trust boundaries
3. TRIAGE   run automated suite (slither + semgrep rules + heuristics)
4. REVIEW   walk the exploit-derived checklist against the code, by hand
5. HYPOTH.  form a concrete "if X then attacker gains Y" hypothesis
6. PROVE    write a Foundry/Echidna PoC that breaks an invariant
7. REPORT   write up with severity (Immunefi V2.2) + working PoC
```

Steps 3 is where this suite saves time. Steps 4–6 are where the money is, and they
stay human.

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
