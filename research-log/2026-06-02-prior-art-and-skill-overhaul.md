# Research Log — 2026-06-02 — Prior-art review + skill/catalog overhaul

## Done
- **Cloned and read the actual source** of the closest comparables: DeFiHackLabs (691
  incidents / 729 fork-replay PoCs), QuillShield skills (11 plugin-skills + BSA
  orchestrator + defender + confidence scoring), Trail of Bits skills (variant-analysis,
  designing-workflow-skills, native per-chain scanners), plus awesome-audits-checklists.
  Clones in `~/prior-art/` (scratch, outside the repo).
- Wrote **`docs/methodology/prior-art.md`** — per-project verdict + what to adopt/reject.
  Key conclusion: don't out-volume DeFiHackLabs; our niche (machine-readable detector +
  paired vuln/safe PoC + coverage sweep as a skill) is defensible. Steal QuillShield's
  scoring + general engines + defender, and ToB's variant rigor + skill-design rules.
- **Rewrote `skills/aegis-audit/SKILL.md` to v2.0** (ToB skill-design conformant):
  trigger-only `description` (was summarizing the workflow — AP-20), `allowed-tools`,
  numbered phases with entry/exit + a verification step, scope-first engine selection
  (token budget), **Rationalizations to Reject**, structured findings, fixed the stale
  "Solana/Move = studied" text (all 10 are coded). Detail split into `references/`:
  `sweep-rigor.md` (root-cause + abstraction ladder + scalable probing), `general-engines.md`
  (state-invariant inference + semantic-guard consistency), `confidence-scoring.md`,
  `finding-format.md`.
- **Sharpened the catalog schema:** added `root_cause` (variant-analysis statement),
  `variant_queries` (the grep family / abstraction ladder), and optional `fork_poc`
  (DeFiHackLabs replay). Backfilled all 10 entries; cross-linked the Beanstalk and
  Balancer V2 DeFiHackLabs replays. YAML still parses (10/10 with new fields).
- **Added `skills/aegis-defender/`** — the blue-team "protect" half: MITIGATE mode (every
  finding → minimal fix proven by a `Safe<X>` PoC that defeats the same exploit, via a
  per-class pattern map) + RELEASE-GATE mode (build integrity, storage-layout/upgrade
  safety, ownership handoff, signer opsec, config drift, monitoring). References:
  `mitigation-patterns.md`, `release-gate-checklist.md`.
- Updated `skills/README`, top `README`, `AGENTS.md` (repo map + loop), `catalog/README`.
- PoC suite unchanged and green: 21/21.

## Takeaways
- Our current skill violated ~8 ToB skill-design rules; the biggest was the description
  summarizing the workflow (causes Claude to shortcut the body). Trigger-only fixed it.
- The "Rationalizations to Reject" pattern (ToB AP-16 / QuillShield) is the single
  cheapest win against missed findings — an LLM talks itself out of real bugs without it.
- Confidence scoring matters most for triaging *unproven Medium hypotheses*; our PoC rule
  already pins proven findings high. Kept that nuance in the reference.
- The defender half finally answers the "and protect them" goal: a finding now ships a
  fix *proven by re-running the exploit against the patch*, not just advice.

## Next
- [ ] Dogfood the v2 skills on a real bounty target; capture friction → sharpen.
- [ ] Item 7 from prior-art.md: native Anchor/Move ports of the EVM-modelled entries.
- [ ] Consider a `.claude-plugin/marketplace.json` so the two skills install as a plugin
      bundle (QuillShield/ToB pattern).
- [ ] Mine Almanax Web3 Security Atlas + DeFiHackLabs 2025–26 incidents for new entries.
