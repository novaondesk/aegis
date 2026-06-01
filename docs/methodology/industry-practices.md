# Industry Practices & Tooling Stack (2026)

How professional auditors and top bounty hunters actually work. The consensus is
**defense-in-depth / multi-layer review** — no single tool is trusted.

## The 4 layers of a modern review

1. **Static analysis** — fast, no execution, finds known-shape bugs.
   - **Slither** (Trail of Bits) — *the* industry standard. 80+ detector types,
     analyzes the Solidity AST, gives severity + exact location. Fast first pass.
   - **Mythril** — symbolic execution, deeper but slower.
   - **Aderyn** (Cyfrin) — Rust-based, newer static analyzer.
2. **Dynamic analysis / fuzzing** — break *properties*, not just happy paths.
   - **Foundry (`forge`)** — the dominant test framework; has fuzzing + invariant
     testing built in. Default choice for PoCs.
   - **Echidna** (Trail of Bits) — property-based fuzzer; you define invariants, it
     hunts inputs that break them.
   - **Medusa** — parallelized, geth-based fuzzer (Echidna's successor lineage).
   - **Recon** — SaaS that bundles Echidna/Medusa/Foundry for invariant testing.
3. **Formal verification** — prove critical invariants hold for *all* inputs.
   - **Certora Prover** — industry formal-verification tool.
   - **Halmos** (a16z) — symbolic testing that reuses Foundry tests.
4. **Manual review** — where the money is. Experienced eyes reading for *intent*
   violations, economic flaws, and cross-function/cross-contract interactions that
   tools structurally cannot see.

## Why automation alone fails

The 2025 lesson — Cetus, Balancer, Yearn were all **audited and still broken**. The
bugs were economic/precision edge cases that pass unit tests and slither-clean. Tools
verify "the code does what it says"; they can't verify "what it says is economically
safe." That gap is the bounty.

## Bounty platform landscape (2026)

- **Immunefi** — largest marketplace. 45k+ researchers, 650+ programs, $110M+ paid,
  protects ~$190B. Uses **Vulnerability Severity Classification System V2.2** (5-level
  scale: impact × privilege × likelihood). **Most programs require a working PoC** —
  no PoC = rejected/downgraded.
- **Sherlock** — stake-to-submit ($250 USDC/report, refunded if valid) + expert triage.
- **Code4rena** — competitive-audit "wardens" model. **Winding down — Immunefi is
  absorbing its clients/researchers** (2026). Historically the best training ground;
  its public reports are a goldmine for pattern-mining.
- Total Web3 bounty market: **$162M+** in available rewards.

## Realistic ramp (per Immunefi)

| Phase | Timeline | Outcome |
|-------|----------|---------|
| Learn | months 1-3 | probably $0 |
| First findings | months 4-6 | low/med, $500-$5k |
| Consistency | months 6-12 | building reputation |
| High/critical | year 2+ | five-figure payouts |

Plan accordingly — this is a skill-compounding game, not a quick score. The suite
shortens phase 1 by encoding what others learned the slow way.

## Free pattern goldmines to mine next

- **Code4rena public reports** — every finding, categorized, with PoCs. Mine these
  into our `checklists/` and `tools/semgrep/`.
- **Solodit** — aggregates findings across audit firms; searchable by class.
- **rekt.news / ChainSec timeline** — incident post-mortems.
- **Trail of Bits "building-secure-contracts"** + the `not-so-smart-contracts` repo.
