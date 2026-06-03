# Research Log — 2026-06-02 — Mining DeFiHackLabs for new catalog entries

## Decision
User asked whether the cloned projects' PoCs were imported. They were **not** — the clones
live in `~/prior-art/` (outside the repo); we took methodology (skills) and two `fork_poc`
cross-links only, no external code. User chose the durable path: **mine DeFiHackLabs for
NEW catalog entries** (study → our own vuln+safe PoC), not vendor their fork-replays.

## Done
- Fixed stale `intake/backlog.md` dedup block: Beanstalk + Rhea are now `promoted`
  (coded); removed the now-redundant `beanstalk-flashloan-gov-2022` seed row.
- Extracted the DeFiHackLabs class distribution (691 incidents): business-logic 109,
  price-manipulation 74, access-control 80+, reentrancy 42, precision ~24, plus a long
  tail (storage-collision, signature-malleability, predictable-RNG, skim, fee-on-transfer).
- Curated **11 distinct new detector classes** not yet in the catalog and appended them to
  `intake/backlog.md`, chosen for reusable detector value (one strong representative per
  class, not ten near-duplicates):
  - P1: ctoken-empty-market-exchange-rate (Hundred/Sonne/Onyx), approval-drain-arbitrary-call
    (Seneca/Socket/Sushi RP2), proxy-storage-collision (Audius), signature-replay-malleability,
    unprotected-privileged-fn (PAID).
  - P2: insecure-randomness, weird-erc20-accounting, incorrect-reward-accounting,
    unverified-flashloan-callback, qubit-bridge-deposit-logic.
  - P3: first-deposit-amm-skim.
- Documented the consumption rule: study post-mortem → docs/exploits → catalog entry
  (root_cause + applies_when + variant_queries) → our own minimal PoC → link DHL as fork_poc.

## Takeaways
- The catalog's gaps cluster in classes DeFiHackLabs is dense in: **approval-drain via
  arbitrary external call** (18 incidents) and **cToken exchange-rate inflation** are the
  two biggest reusable holes; both are P1.
- Value is per *class*, not per incident — DHL has dozens of near-identical reflection-token
  / honeypot rugs that add no detector.

## Next
- [ ] Study + code the top P1: ctoken-empty-market-exchange-rate OR approval-drain-arbitrary-call
      (vuln+safe PoC, the same shape as the existing 10).
- [ ] Then proxy-storage-collision and signature-replay (distinct harness needs).
