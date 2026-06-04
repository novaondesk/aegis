# Aegis

**Exploit-catalog-driven smart contract security auditing.**

> 📖 **Docs site:** https://novaondesk.github.io/aegis/ ·
> 🏴 **Wargames (catalog-driven):** [Ethernaut 31/31](docs/ethernaut-wargame.md) · [Damn Vulnerable DeFi 14/18](docs/dvd-wargame.md)

Aegis evaluates a target contract or protocol against a curated catalog of *studied,
real-world DeFi exploits* — so you can find vulnerabilities **and prove the fix** before
an attacker does. Every studied exploit becomes a structured **detector**; auditing a
target means sweeping it against the whole catalog, proving each hit with a runnable PoC,
then shipping a fix that's proven by a `Safe<X>` PoC defeating the same exploit. Two
composable agent skills: **`aegis-audit`** (red team) and **`aegis-defender`** (blue team).

> The durable asset is the **catalog**, not any one scanner. Tools narrow the haystack;
> the catalog tells you exactly which known attacks to check, and a PoC tells you
> whether the target is actually vulnerable.

## The approach (target → finding → fix)

```
1. RECON & SCOPE   pull source (or decompile via heimdall-rs); pin chain + archetype;
                   map roles, trust boundaries, value flows
2. SWEEP           evaluate the target against EVERY catalog entry whose archetype fits.
                   Each entry's `applies_when` preconditions + `root_cause` + `variant_queries`
                   are checked against the code → a coverage table (HIGH/MED/LOW/N-A).
                   Nothing studied is skipped.
3. REVIEW          general engines (state-invariant inference + semantic-guard consistency)
                   + the exploit-derived checklists catch novel bugs the catalog doesn't list
4. PROVE           Foundry/Anchor/Move PoC that breaks the entry's invariant (vulnerable + safe).
                   For a *deployed* target, prove on a fork of real state (see sim/) — exploit the
                   live contract + its real deps; only the attacker is deployed.
5. SCORE & REPORT  severity (Immunefi V2.2) + confidence score — lead with the fix
6. PROTECT         `aegis-defender` turns each finding into a fix proven by a `Safe<X>` PoC,
                   and release-gates the deploy/upgrade
```

The sweep is what makes this repeatable: "we checked all N known exploits against this
target" is a coverage claim, not a vibe. See [`catalog/README.md`](catalog/README.md), and
[`docs/methodology/prior-art.md`](docs/methodology/prior-art.md) for how Aegis compares to
DeFiHackLabs / QuillShield / Trail of Bits.

## The catalog

[`catalog/exploits.yaml`](catalog/exploits.yaml) is the single source of truth. Each
entry distills a real incident into a detector: the target shapes it applies to
(`archetypes`/`chains`), the `applies_when` preconditions, a one-line `root_cause`
statement, the `variant_queries` grep-family that hunts the bug across a target, the
`invariant` that breaks, and links to the deep-dive case study, the runnable PoC, and
(where one exists) a DeFiHackLabs mainnet-fork replay (`fork_poc`).

| Exploit | Class | Chain | Status |
|---|---|---|---|
| ERC-4626 share-inflation | SC07/SC02 | EVM | ✅ coded PoC |
| Read-only reentrancy (Curve class) | SC08 | EVM | ✅ coded PoC |
| Balancer V2 rounding ($128M) | SC07 | EVM (6 chains) | ✅ coded PoC |
| Cashio infinite-mint ($52.8M) | SC05/SC02 | Solana (EVM model) | ✅ coded PoC |
| Cetus CLMM overflow ($223M) | SC07/SC09 | Sui/Move (EVM model) | ✅ coded PoC |
| Loopscale spot-price oracle ($5.8M) | SC03/SC02 | Solana (EVM model) | ✅ coded PoC |
| Loopscale unvalidated CPI ($5.8M) | SC03/SC05 | Solana (EVM model) | ✅ coded PoC |
| Mango oracle manipulation ($114M) | SC03/SC02 | Solana (EVM model) | ✅ coded PoC |
| Beanstalk governance flash-loan ($181M) | SC02/SC04 | EVM | ✅ coded PoC |
| Rhea Finance multi-hop slippage ($18.4M) | SC02/SC07 | NEAR (EVM model) | ✅ coded PoC |
| cToken empty-market exchange-rate inflation (~$7M+) | SC07/SC02 | EVM | ✅ coded PoC |
| Router arbitrary-call approval drain (Socket/Seneca) | SC05/SC01 | EVM | ✅ coded PoC |
| Upgradeable-proxy storage-slot collision ($6M) | SC01 | EVM | ✅ coded PoC |
| Signature replay + ecrecover malleability | SC01 | EVM | ✅ coded PoC |
| Missing access control on a privileged fn (PAID) | SC01 | EVM | ✅ coded PoC |
| Predictable on-chain randomness | SC09 | EVM | ✅ coded PoC |
| Fee-on-transfer / weird-ERC20 accounting | SC02 | EVM | ✅ coded PoC |
| MasterChef reward-debt desync (double-claim) | SC02 | EVM | ✅ coded PoC |
| Unverified flash-loan / external callback | SC05/SC01 | EVM | ✅ coded PoC |
| Bridge credits a no-code-token deposit (Qubit $80M) | SC02 | EVM | ✅ coded PoC |
| AMM-pair first-deposit / share-skim | SC07 | EVM | ✅ coded PoC |

`coded` = runnable PoC in [`poc/`](poc/). *(EVM model)* = the incident was on a non-EVM
chain (Solana/Move/NEAR) and the PoC reproduces the same broken invariant in Solidity, so
it runs in the Foundry harness; a native Anchor/Move port is the fidelity follow-up.

## Use it as agent skills

Aegis ships as two composable [Agent Skills](skills/):
- **[`aegis-audit`](skills/aegis-audit/SKILL.md)** (red team) — recon & scope → catalog
  sweep → state-invariant + semantic-guard engines → PoC → scored report.
- **[`aegis-defender`](skills/aegis-defender/SKILL.md)** (blue team) — turns findings into
  fixes **proven by a `Safe<X>` PoC**, plus a deploy/upgrade release-gate.

Register the repo's `skills/` dir in place (so the `../../catalog` links resolve) — e.g.
symlink it, or add it to Hermes `skills.external_dirs`; see [`skills/`](skills/). Then ask
to *"audit this contract"* / *"evaluate this target against known exploits"* (audit) or
*"remediate these findings"* / *"is this safe to deploy?"* (defender).

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
| `skills/` | Aegis as loadable agent skills (`aegis-audit` red team, `aegis-defender` blue team) |
| `docs/exploits/` | Deep-dive case studies — one file per incident/class |
| `docs/vuln-classes/` | Taxonomy (OWASP SC Top 10 2026 + X-classes) |
| `docs/methodology/` | Industry practice, tooling stack, sources |
| `checklists/` | Exploit-justified per-class review checklists |
| `tools/` | Slither config, semgrep rules, Foundry invariant templates |
| `poc/` | Runnable Foundry PoCs — minimal *models* of catalog patterns (vulnerable + safe + test) |
| `sim/` | **Fork-simulation** — exploit the *real deployed target* on a forked chain (the PROVE phase for live targets); 4 real incident replays |
| `ethernaut/` | **Wargame validation** — Aegis solves the Ethernaut CTF via the catalog sweep (31/31); see [report](docs/ethernaut-wargame.md) |
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

## Status — v2.1.0

See [`CHANGELOG.md`](CHANGELOG.md) and [`research-log/`](research-log/).
- **Catalog:** 27 exploit detectors (25 with runnable model PoCs, 2 studied), machine-readable +
  agent-driven. v2.0.0 added 11 DeFiHackLabs-mined classes; v2.1.0 added Nova's 5 May-2026 studies
  (3 coded) and the fork-simulation capability.
- **Fork-simulation (`sim/`):** prove findings against *real deployed targets* on a forked chain.
  4 real incident replays pass against mainnet state — Socket Gateway (approval drain, ~656k USDC),
  Audius (proxy storage collision, ~18.56M AUDIO), DAO Maker (unprotected init, 5.76M DERC), and
  Beanstalk (flashloan governance, ~$42M USDC profit on a ~$1B Aave loan).
- **Skills:** `aegis-audit` (red — catalog sweep + general engines + scored PoC report, now with a
  Fork-PROVE mode) and `aegis-defender` (blue — fixes proven by `Safe<X>`, deploy/upgrade release-gate).
- **Pattern library:** OWASP SC Top 10 (2026) taxonomy; 370-item Solodit EVM backstop;
  exploit-justified front-line checklist with archetype playbooks.
- **Next:** point fork-sim at a live in-scope target (RECON → sweep → fork-PROVE); native
  Solana/Move harnesses for non-EVM targets.
