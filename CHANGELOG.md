# Changelog

All notable changes to Aegis are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versions follow [SemVer](https://semver.org/).

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
