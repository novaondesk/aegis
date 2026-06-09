# Aegis

**Exploit-catalog-driven smart contract security auditing.**

[![CI](https://github.com/novaondesk/aegis/actions/workflows/ci.yml/badge.svg)](https://github.com/novaondesk/aegis/actions/workflows/ci.yml)

> 📖 **Docs site:** https://novaondesk.github.io/aegis/ ·
> 🏴 **Wargames (catalog-driven):** [Ethernaut 40/40](docs/ethernaut-wargame.md) · [Damn Vulnerable DeFi 18/18](docs/dvd-wargame.md)

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

The table and counts below are **generated from `exploits.yaml`**
(`python3 tools/gen_catalog_table.py`); CI fails if they drift.

<!-- BEGIN GENERATED: catalog-counts -->
**40 detectors — 33 with runnable PoCs (CI-enforced), 5 studied (PoC pending), 2 documented (case study).**
<!-- END GENERATED: catalog-counts -->

<!-- BEGIN GENERATED: catalog-table -->
| Exploit | Class | Chain | Loss | Status |
|---|---|---|---|---|
| ERC-4626 First-Depositor / Share-Inflation | SC07/SC02 | EVM | recurring | ✅ coded PoC |
| Read-Only Reentrancy (Curve get_virtual_price class) | SC08 | EVM | recurring | ✅ coded PoC |
| Balancer V2 ComposableStablePool — Rounding Inconsistency | SC07 | EVM/multi | $128M | ✅ coded PoC |
| Cashio App — Infinite Mint via Missing Account Validation | SC05/SC02 | Solana *(EVM model)* | $52.8M | ✅ coded PoC |
| Cetus CLMM — Flawed Overflow Check (checked_shlw) | SC07/SC09 | Sui/Move *(EVM model)* | $223M | ✅ coded PoC |
| Loopscale — Single Spot-Price Collateral Valuation | SC03/SC02 | Solana *(EVM model)* | $5.8M | ✅ coded PoC |
| Loopscale — Unvalidated CPI Target (spoofed RateX program) | SC03/SC02/SC05 | Solana *(EVM model)* | $5.8M | ✅ coded PoC |
| Mango Markets — Low-Liquidity Collateral Oracle Manipulation | SC03/SC02 | Solana *(EVM model)* | $114M | ✅ coded PoC |
| Beanstalk Governance Flash-Loan Attack | SC02/SC04 | EVM | $181M | ✅ coded PoC |
| Rhea Finance multi-hop swap route slippage inflation | SC02/SC07 | NEAR/multi *(EVM model)* | $18.4M | ✅ coded PoC |
| TrustedVolumes — Public Setter on Access Control Mapping | SC02 | EVM | $6.7M | ✅ coded PoC |
| Verus Bridge — Forged Merkle Proof Cross-Chain Withdrawal | SC02 | EVM/multi | $11.6M | ✅ coded PoC |
| THORChain TSS/GG20 Key Extraction via Malformed Paillier Modulus | X04 | multi | $10.8M | 📚 studied |
| Ekubo — Flash-Accounting Callback Calldata Injection / Standing Approval Drain | SC02/SC02-CB | EVM | $1.4M | 📚 studied |
| Kelp DAO — LayerZero Single-DVN Bridge Drain | X01/X01-BRIDGE | EVM/multi | $292M | ✅ coded PoC |
| Compound-fork cToken empty-market exchange-rate inflation | SC07/SC02 | EVM | recurring | ✅ coded PoC |
| Router arbitrary-external-call approval drain | SC05/SC01 | EVM | recurring | ✅ coded PoC |
| Upgradeable-proxy storage-slot collision | SC01 | EVM | $6M | ✅ coded PoC |
| Signature replay + ecrecover malleability | SC01 | EVM | recurring | ✅ coded PoC |
| Missing access control on a privileged function | SC01 | EVM | recurring | ✅ coded PoC |
| Predictable on-chain randomness | SC09 | EVM | recurring | ✅ coded PoC |
| Fee-on-transfer / weird-ERC20 accounting (received != requested) | SC02 | EVM | recurring | ✅ coded PoC |
| MasterChef-style reward-debt desync (double-claim) | SC02 | EVM | recurring | ✅ coded PoC |
| Unverified flash-loan / external callback | SC05/SC01 | EVM | recurring | ✅ coded PoC |
| Bridge credits a no-code-token deposit | SC02 | EVM | $80M | ✅ coded PoC |
| AMM-pair first-deposit / share-skim manipulation | SC07 | EVM | recurring | ✅ coded PoC |
| State-changing checks-effects-interactions reentrancy | SC08 | EVM | recurring | ✅ coded PoC |
| Meta-transaction _msgSender() spoofing (ERC-2771 forwarder trust) | SC01 | EVM | recurring | ✅ coded PoC |
| Calldata / ABI smuggling (validate one byte range, execute another) | SC05/SC01 | EVM | recurring | ✅ coded PoC |
| Forced-ether balance assumption (selfdestruct / pre-funding breaks balance logic) | SC02 | EVM | recurring | ✅ coded PoC |
| DoS via reverting recipient / push-payment + unbounded-loop griefing | SC10/SC02 | EVM | recurring | ✅ coded PoC |
| Yearn yETH Solver Divergence + Underflow Infinite Mint | SC07/SC02 | EVM | $9M | 📚 studied |
| Transit Finance — Legacy Contract + Standing Approval Drain | SC02/SC02-LEGACY/X05 | TRON/EVM | $1.88M | 📚 studied |
| Hyperbridge — MMR Out-of-Bounds Leaf Verification Bypass | SC02/SC02-BRIDGE | EVM/Polkadot | $237k | 📚 studied |
| ECDSA nonce (k) reuse → private-key extraction | SC01 | EVM | recurring | ✅ coded PoC |
| TAC Bridge — Jetton Wallet Code-Hash Verification Bypass | SC02 | TON/EVM *(EVM model)* | $2.85M | ✅ coded PoC |
| ZetaChain GatewayEVM — Three-Defect Cross-Chain Approval Drain | SC02/SC05/SC01 | EVM/multi | $334k | ✅ coded PoC |
| ATOHook — Solady ReentrancyGuard Storage Slot Collision | SC-storage-layout | EVM | $14.41M | ✅ coded PoC |
| Drift Protocol — Oracle Accepts Fabricated Token as Collateral (No Liquidity Validation) | SC03/X02/X03 | Solana | $285M | 📝 documented |
| Wasabi Protocol — UUPS Proxy Upgrade via Compromised Single-Owner Admin Key | X03 | EVM/multi | $5.5M | 📝 documented |
<!-- END GENERATED: catalog-table -->

`coded` = runnable PoC in [`poc/`](poc/). *(EVM model)* = the incident was on a non-EVM
chain (Solana/Move/NEAR) and the PoC reproduces the same broken invariant in Solidity, so
it runs in the Foundry harness; a native Anchor/Move port is the fidelity follow-up.

## Use it as agent skills

Aegis ships as two composable [Agent Skills](skills/):
- **[`aegis-audit`](skills/aegis-audit/SKILL.md)** (red team) — recon & scope → catalog
  sweep → state-invariant + semantic-guard engines → PoC → scored report.
- **[`aegis-defender`](skills/aegis-defender/SKILL.md)** (blue team) — turns findings into
  fixes **proven by a `Safe<X>` PoC**, plus a deploy/upgrade release-gate.

Register the repo's `skills/` dir in place (so the `../../catalog` links resolve) — the
skills work with any agent runtime that discovers `SKILL.md` files:

- **Claude Code:** symlink the skill dirs into your project's `.claude/skills/`
  (or `~/.claude/skills/` for all projects): `ln -s /path/to/aegis/skills/aegis-audit .claude/skills/`
- **Hermes:** add `skills/` to `skills.external_dirs` in `~/.hermes/config.yaml`
- **Other frameworks (Cursor, custom agents):** point the agent at
  [`skills/aegis-audit/SKILL.md`](skills/aegis-audit/SKILL.md) as a system-prompt include;
  it is self-contained prose with relative links into the repo.

Then ask to *"audit this contract"* / *"evaluate this target against known exploits"*
(audit) or *"remediate these findings"* / *"is this safe to deploy?"* (defender).

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
| `ethernaut/` | **Wargame validation** — Aegis solves the Ethernaut CTF via the catalog sweep (40/40); see [report](docs/ethernaut-wargame.md) |
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

## Status — v2.7.0

See [`CHANGELOG.md`](CHANGELOG.md) and [`research-log/`](research-log/). Detector counts
live in the generated table above — never hand-maintained here.
- **Catalog:** machine-readable + agent-driven, validated in CI
  (`tools/validate_catalog.py`). v2.0.0 added 11 DeFiHackLabs-mined classes; v2.1.0 added Nova's 5 May-2026 studies
  (3 coded) and the fork-simulation capability; v2.4.0 added 4 wargame-mined classes (meta-tx spoof,
  ABI smuggling, forced-ether, DoS-griefing); v2.5.0 added `ecdsa-nonce-reuse-key-extraction`
  (on-chain key recovery via the modexp precompile, from Ethernaut ImpersonatorTwo); v2.6.0 added
  `tac-bridge-jetton-impersonation` (code-hash-without-provenance) and **completed the Ethernaut
  wargame — 40/40** (EllipticToken raw-ECDSA forgery, Cashback forged-7702 designator,
  NotOptimisticPortal selector-collision + forged L2 proof); v2.7.0 added CI (forge tests +
  catalog validation + README-drift check on every push) and closed the schema gaps it caught.
- **Fork-simulation (`sim/`):** prove findings against *real deployed targets* on a forked chain.
  4 real incident replays pass against mainnet state — Socket Gateway (approval drain, ~656k USDC),
  Audius (proxy storage collision, ~18.56M AUDIO), DAO Maker (unprotected init, 5.76M DERC), and
  Beanstalk (flashloan governance, ~$42M USDC profit on a ~$1B Aave loan).
- **Skills:** `aegis-audit` (red — catalog sweep + general engines + scored PoC report, now with a
  Fork-PROVE mode) and `aegis-defender` (blue — fixes proven by `Safe<X>`, deploy/upgrade release-gate).
- **Pattern library:** OWASP SC Top 10 (2026) taxonomy; 370-item Solodit EVM backstop;
  exploit-justified front-line checklist with archetype playbooks.
- **Next:** point fork-sim at a live in-scope target (RECON → sweep → fork-PROVE); native
  Solana/Move harnesses for non-EVM targets; negative fixtures (known-safe contracts the
  sweep must NOT flag) to measure false-positive rate, not just exploit/fix behavior.
