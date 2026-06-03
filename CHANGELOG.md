# Changelog

All notable changes to Aegis are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versions follow [SemVer](https://semver.org/).

## [2.0.0] — 2026-06-03

Catalog expansion release: **+11 distinct exploit detector classes** mined from
DeFiHackLabs, each shipped as the full Aegis unit (deep-dive case study + machine-readable
catalog entry with `root_cause`/`applies_when`/`variant_queries` + a runnable
`Vulnerable<X>` + `Safe<X>` + Foundry test). The catalog grows from **10 → 21** coded
detectors; the full `poc/` suite is green (44 tests).

### Added
- **11 new coded catalog entries** (all with vulnerable+safe PoCs):
  - `ctoken-empty-market-exchange-rate` (SC07/SC02) — Compound-fork empty-market exchange-rate
    inflation, distinct from the ERC-4626 case.
  - `approval-drain-arbitrary-call` (SC05/SC01) — router forwards an attacker-chosen call while
    holding users' approvals (Socket/Seneca/Sushi class).
  - `proxy-storage-collision` (SC01) — upgradeable-proxy admin slot overwritten by an impl var
    (Audius-class); EIP-1967 fix.
  - `signature-replay-malleability` (SC01) — no nonce/domain + ecrecover high-s malleability.
  - `unprotected-privileged-fn` (SC01) — missing access control on mint/initialize (PAID-class).
  - `insecure-randomness` (SC09) — predictable block-variable RNG.
  - `weird-erc20-accounting` (SC02) — fee-on-transfer / received-!=-requested over-crediting.
  - `incorrect-reward-accounting` (SC02) — MasterChef reward-debt desync / double-claim.
  - `unverified-flashloan-callback` (SC05/SC01) — callback with no `msg.sender`/`initiator` check.
  - `bridge-deposit-no-code-token` (SC02) — bridge credits a deposit of a codeless token (Qubit $80M).
  - `first-deposit-amm-skim` (SC07) — UniV2-fork first-deposit share-skim (no MINIMUM_LIQUIDITY lock).
- Matching deep-dive case studies under `docs/exploits/` and PoC rows in `poc/README.md`.

### Changed
- README catalog table + `Status` bumped to v2.0.0 (21 detectors).
- `intake/backlog.md` "Mined from DeFiHackLabs" rows flipped `todo → promoted`.

[2.0.0]: https://github.com/novaondesk/aegis/releases/tag/v2.0.0

## [1.0.0] — 2026-06-02

First stable release. The project graduates from "DeFi Bounty Suite" (a research
scaffold) into **Aegis** — an exploit-catalog-driven auditing toolset usable directly
by agents.

### Added
- **Exploit catalog** (`catalog/exploits.yaml`) — the single source of truth: 8 studied
  real-world exploits distilled into machine-readable detectors with checkable
  `applies_when` preconditions, probes, invariants, and links to deep-dives + PoCs.
  Schema + usage in `catalog/README.md`.
- **`aegis-audit` agent skill** (`skills/aegis-audit/`) — drives a catalog *sweep*:
  evaluate a target against every applicable known exploit → coverage table → ranked
  hypotheses → PoC → report.
- 5 new exploit case studies (PR #7): Mango oracle, Loopscale (spot-price + unvalidated
  CPI), Cashio infinite-mint, Balancer V2 rounding.

### Changed
- **Renamed** the project to **Aegis** (repo `novaondesk/defi-bounty-suite` →
  `novaondesk/aegis`); README, AGENTS.md, and skill rebranded with a defensive
  "find-and-fix" framing.
- The contribution loop now requires a **catalog entry** for every exploit studied
  (4 places to update, not 3); definition-of-done gained a catalog-parse check.
- Skill `smart-contract-bounty-review` → `aegis-audit`, restructured around the sweep.

### Existing (pre-1.0 foundation)
- OWASP SC Top 10 (2026) taxonomy + X-classes; exploit-justified master checklist with
  archetype playbooks; 370-item Solodit EVM backstop.
- Coded PoCs: ERC-4626 share-inflation, read-only reentrancy (Foundry).
- Tooling: slither config, semgrep rule set, Foundry invariant templates; tooling
  landscape + methodology docs.

[1.0.0]: https://github.com/novaondesk/aegis/releases/tag/v1.0.0
