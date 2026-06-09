# Changelog

All notable changes to Aegis are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versions follow [SemVer](https://semver.org/).

## [2.7.0] — 2026-06-09

Self-enforcement: the repo now holds itself to its own "prove it" bar. Acting on an external
review of the published repo.

### Added
- **CI** (`.github/workflows/ci.yml`) on every push/PR + a status badge in the README. Three jobs:
  catalog validation, the full `poc/` PoC suite (78 tests), and the Ethernaut wargame (40/40).
  `sim/` (mainnet-fork replays, needs RPC) and `dvd/` (external repo) are intentionally out of CI scope.
- **`tools/validate_catalog.py`** — enforces the catalog schema as a contract: required fields,
  `status: coded` ⇔ `poc`/`poc_cmd` set + file exists (and the inverse for `studied`), `doc`/`fork_poc`
  repo paths resolve, and `class`/`checklist`/`semgrep` ids resolve to their source files.
- **`tools/gen_catalog_table.py`** — generates the README catalog table + counts from
  `exploits.yaml` (single source of truth); `--check` fails CI on drift. README counts are no longer
  hand-maintained.
- **`LICENSE`** (MIT) at the repo root, matching the skills' declared license.
- **PoC fidelity discipline** in `aegis-audit`: findings backed only by an EVM-model PoC for a
  non-EVM target must be labelled *illustrative of the class, not a faithful repro* — a native
  Anchor/Move port is the follow-up that upgrades them to proven (`references/finding-format.md`).
- Generic skill-loading instructions (Claude Code / Hermes / other runtimes) in the README.
- New taxonomy classes **X04** (threshold-signature / key-gen protocol flaw) and **X05**
  (legacy / deprecated contract surface) in `docs/vuln-classes/`, backing the THORChain and
  Transit Finance entries.

### Fixed
- Validation surfaced and closed real catalog gaps: `tools/semgrep/solidity-patterns.yml` was
  empty (25 referenced rule ids had no rule) — restored + extended to cover every referenced id;
  missing `summary`/`root_cause`/`variant_queries` on five entries; two `studied` entries carried
  `poc: n/a` (now `null`); non-vocabulary chain ids (`ethereum`/`multi-chain`) normalised.
- `ethernaut/` builds and tests clean on a fresh checkout: restored the dropped
  `openzeppelin-contracts-06` remapping (the full suite had been uncompilable since the oz06 move),
  added per-profile `skip` lists, and made the CoinFlip PoC robust to Foundry 1.7.x `blockhash`
  semantics. 40/40 green from a cold cache.
- Reconciled the validator with the freshly-merged Drift/Wasabi/Zeta/ATOHook entries (catalog
  36 → 40): formalised `documented` as the third lifecycle status (case study only; detector
  fields not yet required), taught the validator to read the per-ecosystem checklists (Solana,
  Solodit, L2) not just the master, added the 3 ZetaChain semgrep rules + the `SC-storage-layout`
  sub-class, and normalised the Wasabi multi-chain `chains` list. poc suite now 78 green.

## [2.5.0] — 2026-06-04

Merged Nova's PR #10 (research-rolling).

### Added
- **3 new studied catalog entries** from Nova's research (catalog 31 → 34; all `studied`, PoCs pending):
  `yearn-yeth-solver-underflow` ($9M — Newton-Raphson solver divergence + `unsafe_sub` underflow),
  `transit-finance-legacy-approval-drain` ($1.88M — "deprecated" ≠ disabled; standing approvals on a
  still-callable legacy contract), `hyperbridge-mmr-leaf-index` ($237K — MMR out-of-bounds leaf
  verification bypass). Case studies under `docs/exploits/`; new checklist sections (SC02-SOLVER/REINIT/POL,
  SC07-UNSAFE, X05 Contract-Lifecycle, SC02-MMR-BOUNDS/PROOF-BIND/CHALLENGE-PERIOD).

### Merge notes
- Resolved 13 conflicts by keeping `main`'s newer state (catalog 31 + wargame detectors, docs site,
  ethernaut shims) and integrating Nova's net-new content. `poc` 64/64 and `ethernaut` 34/34 stay green.

## [2.4.0] — 2026-06-04

DVD v4 18/18 + 4 wargame-mined detectors.

### Added
- **Damn Vulnerable DeFi v4 → 18/18** (was 16/18). Solved the last two in the real harness:
  **Wallet Mining** (slot-0 `needsInit`/`upgrader` storage-collision re-`init`, Safe `saltNonce=13`
  create2 onto the deposit address, off-chain Safe-sig drain — all in the player's single tx) and
  **Curvy Puppet** (Curve `get_virtual_price` read-only-reentrancy liquidation on a mainnet fork @
  20190356: flash-loan 80k ETH + 220k stETH, inflate vp ~4.3× in the `remove_liquidity` ETH callback,
  liquidate all 3 positions in one reentrant sweep). Solutions in `dvd/solutions/test/`.
- **4 new catalog detectors** mined from the wargames (catalog 27 → 31 coded; +11 PoC tests, all green):
  `meta-tx-msgsender-spoof` (SC01, DVD Naive Receiver), `calldata-abi-smuggling` (SC05/SC01, DVD ABI
  Smuggling + Ethernaut Switch/HigherOrder), `forced-ether-balance-assumption` (SC02, Ethernaut
  Force/King), `dos-griefing-revert` (SC10/SC02, Ethernaut King/Denial). Each: case study +
  catalog entry + `Vulnerable<X>`/`Safe<X>`/test + checklist item + semgrep rule.

### Changed
- Docs site: `the-catalog` 27 → 31 detectors, `pocs` +4 blocks, both wargame reports' gap lists
  updated to link the promoted detectors.

## [2.3.0] — 2026-06-03

Full Ethernaut wargame coverage.

### Added
- **All 31 Ethernaut levels solved** in `ethernaut/` (was 5) — each exploited locally in Foundry
  against the real level contract, asserting the level's own win condition. Older-pragma levels
  (^0.5/^0.6/<0.7) via `deployCode`; minimal OZ shims under `ethernaut/src/vendor/` + `src/helpers/`.
- **10 levels caught by an exact catalog detector** (the validation): `proxy-storage-collision`
  (Delegation, Preservation, PuzzleWallet), `unprotected-privileged-fn` (Fallout, Motorbike,
  Fallback), `loopscale-oracle-spot-price` (Dex, DexTwo), `insecure-randomness` (CoinFlip),
  `cei-reentrancy` (Reentrance).
- The other 21 are solved with general techniques that **surface catalog gaps** (DoS, forced-ether,
  info-exposure, integer/storage underflow, tx.origin, calldata, untrusted-interface) — documented
  as a detector to-do list in the report.

### Changed
- `docs/ethernaut-wargame.md` rewritten with the full 31-level coverage table + gaps section;
  README / docs site / `ethernaut/README.md` updated 5/5 → 31/31.

[2.3.0]: https://github.com/novaondesk/aegis/releases/tag/v2.3.0

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
