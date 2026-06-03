# Aegis

**Exploit-catalog-driven smart contract security auditing.**

Aegis evaluates a target contract or protocol against a curated catalog of *studied,
real-world DeFi exploits* — so you can find vulnerabilities and fix them before an
attacker does. Every studied exploit becomes a structured **detector**; auditing a
target means sweeping it against the whole catalog, then proving each hit with a
runnable PoC.

> The durable asset is the **catalog**, not any one scanner. Tools narrow the haystack;
> the catalog tells you exactly which known attacks to check, and a PoC tells you
> whether the target is actually vulnerable.

## The approach (target → finding)

```
1. RECON   pull source (or decompile via heimdall-rs); pin chain + archetype
2. SWEEP   evaluate the target against EVERY catalog entry whose archetype fits.
           Each entry's `applies_when` preconditions are checked against the code →
           a coverage table of HIGH / MED / N-A verdicts. Nothing studied is skipped.
3. REVIEW  walk the exploit-derived checklist for what the catalog doesn't cover
4. PROVE   write a Foundry/Anchor/Move PoC that breaks the entry's invariant
5. REPORT  severity (Immunefi V2.2) + the fix — the point is a safer target
```

The sweep is what makes this repeatable: "we checked all N known exploits against this
target" is a coverage claim, not a vibe. See [`catalog/README.md`](catalog/README.md).

## The catalog

[`catalog/exploits.yaml`](catalog/exploits.yaml) is the single source of truth. Each
entry distills a real incident into a detector: the target shapes it applies to, the
preconditions to check, how to probe, the invariant that breaks, and links to the
deep-dive case study + runnable PoC.

| Exploit | Class | Chain | Status |
|---|---|---|---|
| ERC-4626 share-inflation | SC07/SC02 | EVM | ✅ coded PoC |
| Read-only reentrancy (Curve class) | SC08 | EVM | ✅ coded PoC |
| Balancer V2 rounding ($128M) | SC07 | EVM (6 chains) | 📄 studied |
| Cashio infinite-mint ($52.8M) | SC05/SC02 | Solana | 📄 studied |
| Cetus CLMM overflow ($223M) | SC07/SC09 | Sui/Move | 📄 studied |
| Loopscale spot-price oracle ($5.8M) | SC03/SC02 | Solana | 📄 studied |
| Loopscale unvalidated CPI ($5.8M) | SC03/SC05 | Solana | 📄 studied |
| Mango oracle manipulation ($114M) | SC03/SC02 | Solana | 📄 studied |
| Beanstalk governance flash-loan ($181M) | SC02/SC04 | EVM | ✅ coded PoC |
| Rhea Finance multi-hop slippage ($18.4M) | SC02/SC07 | NEAR (EVM model) | ✅ coded PoC |

`coded` = runnable PoC in [`poc/`](poc/); `studied` = deep-dive case study, PoC not yet ported.

## Use it as an agent skill

Aegis ships as a loadable [Agent Skill](skills/aegis-audit/SKILL.md) so any Claude/agent
can run the sweep for you:
```bash
cp -r skills/aegis-audit ~/.claude/skills/    # or <project>/.claude/skills/
```
Then ask it to *"audit this contract"* or *"evaluate this target against known
exploits."* It loads the catalog, runs the sweep, and drives recon → PoC → report. See
[`skills/`](skills/).

## Tooling

The sweep is accelerated by automated first-pass tools; full landscape +
integration notes in [`docs/methodology/security-tooling-landscape.md`](docs/methodology/security-tooling-landscape.md).

- **Slither / semgrep** — static first pass. `tools/slither/`, `tools/semgrep/` (one
  rule per extracted pattern). Most catalog entries are *not* statically flagged — the
  preconditions are how you find those.
- **Foundry (`forge`)** — primary PoC + fuzz/invariant harness. PoCs live in `poc/`.
- **Echidna / Medusa, Halmos / Certora** — property fuzzing and symbolic/formal, strongest
  on the arithmetic/precision class (SC07).
- **heimdall-rs** — decompiles unverified bytecode into reviewable pseudo-source for recon.

## Repo layout

| Path | What lives here |
|---|---|
| `catalog/` | **The exploit catalog** — `exploits.yaml` (sweep source) + schema |
| `skills/` | Aegis as a loadable agent skill (`aegis-audit`) |
| `docs/exploits/` | Deep-dive case studies — one file per incident/class |
| `docs/vuln-classes/` | Taxonomy (OWASP SC Top 10 2026 + X-classes) |
| `docs/methodology/` | Industry practice, tooling stack, sources |
| `checklists/` | Exploit-justified per-class review checklists |
| `tools/` | Slither config, semgrep rules, Foundry invariant templates |
| `poc/` | Runnable Foundry PoCs (vulnerable + safe + exploit test) |
| `research-log/` | Dated log of what we looked at and found |

## Contributing (agents & humans)

Read **[`AGENTS.md`](AGENTS.md)** first — it's the contract for how Nova and other
agents contribute so the work compounds. The core loop: study an exploit → reproduce
with a runnable PoC → write a case study → **add a catalog entry** + checklist item +
detector → log.

## Ground rules

- **Defensive / responsible disclosure only.** We evaluate *in-scope* bounty targets,
  public post-mortems, or our own deployments — to get bugs fixed. No out-of-scope
  contracts, no live exploitation.
- Every claimed finding needs a **reproducible PoC** before it counts.
- Every catalog entry documents *why* the pattern matters with a real loss attached —
  no theory-only entries.

## Status — v1.0.0

First stable release. See [`CHANGELOG.md`](CHANGELOG.md) and [`research-log/`](research-log/).
- **Catalog:** 10 exploit detectors (4 with coded PoCs), machine-readable + agent-driven.
- **Skill:** `aegis-audit` runs the catalog sweep end to end.
- **Pattern library:** OWASP SC Top 10 (2026) taxonomy; 370-item Solodit EVM backstop;
  exploit-justified front-line checklist with archetype playbooks.
- **Next:** port `studied` Solana/Move entries to coded PoCs; grow the catalog per the
  research day-plans.
