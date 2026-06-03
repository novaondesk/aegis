# Changelog

All notable changes to Aegis are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versions follow [SemVer](https://semver.org/).

## [2.2.0] — 2026-06-03

Independent benchmark + documentation site. Aegis is validated against a third-party CTF, and the
docs are published.

### Added
- **`ethernaut/` wargame harness** — Aegis solves OpenZeppelin's Ethernaut CTF **5/5** using only
  the catalog sweep (RECON → SWEEP → PROVE), each level exploited locally in Foundry against the real
  level contract:
  - #3 CoinFlip → `insecure-randomness`; #6 Delegation → `proxy-storage-collision`;
    #10 Reentrance → `read-only-reentrancy` (SC08 family); #22 Dex → `loopscale-oracle-spot-price`
    (price-manipulation family); #25 Motorbike → `unprotected-privileged-fn`.
- **Wargame report** — [`docs/ethernaut-wargame.md`](docs/ethernaut-wargame.md): per level, the
  matched detector, the exact `applies_when` signals that held, the root cause, and the proof. Shows
  the same detectors span CTF and mainnet (Delegation↔Audius, Dex↔Mango/Loopscale, Motorbike↔DAO Maker).
- **GitHub Pages docs site** (`docs/_config.yml` + `docs/index.md`, cayman theme) at
  https://novaondesk.github.io/aegis/ .

- **`cei-reentrancy` catalog entry + PoC** (`poc/test/CeiReentrancy.t.sol`) — the state-changing
  checks-effects-interactions reentrancy detector, prompted by the Reentrance level. Catalog → 27
  entries (25 coded). All 5 wargame levels now map to an exact catalog entry.

[2.2.0]: https://github.com/novaondesk/aegis/releases/tag/v2.2.0

## [2.1.0] — 2026-06-03

Fork-simulation capability + catalog growth. Aegis can now prove findings against **forked real
state** (the real deployed target + its live dependencies), not just minimal models.

### Added
- **`sim/` fork-simulation harness** — Foundry project that forks a chain at a pinned block and
  exploits the live target; you deploy only the attacker. Reuses `poc/`'s forge-std; RPC via a
  gitignored `.env`. Documented in `sim/README.md` + `skills/aegis-audit/references/fork-simulation.md`.
- **4 real incident replays** (ground-truth `fork_poc`s, all passing against mainnet state):
  - Socket Gateway 2024-01 (`approval-drain-arbitrary-call`) — drains a real victim's ~656k USDC.
  - Audius 2022-07 (`proxy-storage-collision`) — seizes the real governance proxies, drains ~18.56M AUDIO.
  - DAO Maker 2021-09 (`unprotected-privileged-fn`) — unprotected `init` → `emergencyExit` drains 5.76M DERC.
  - Beanstalk 2022-04 (`beanstalk-governance-flashloan`) — flash-loans ~$1B (Aave) into the silo for
    an instant supermajority, `emergencyCommit`s a malicious BIP, drains the protocol, nets ~$42M USDC.
- **`aegis-audit` Phase 5 gains a Fork-PROVE mode** for deployed targets.
- **3 catalog entries ported to coded PoCs** from Nova's PR #9 studies: `trustedvolumes-access-control`,
  `verus-bridge-merkle-forgery`, `kelp-dao-layerzero-dvn-1-1` (catalog 24 coded / 2 studied).

### Changed
- README repo-layout + PROVE step now reference `sim/`; the three replayed catalog entries point
  their `fork_poc` at the real `sim/` replays.

[2.1.0]: https://github.com/novaondesk/aegis/releases/tag/v2.1.0

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
