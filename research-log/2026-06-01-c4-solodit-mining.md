# 2026-06-01 — Code4rena / Solodit checklist mining

## What we did
- Code4rena is winding down (Immunefi absorbing) — its + Solodit's findings are the
  best free pattern goldmine. Targeted the **Cyfrin/Solodit aggregated audit-checklist**.
- Pulled `checklist.json` from `github.com/Cyfrin/audit-checklist`, flattened it to
  **370 leaf check items across 13 top categories** → `checklists/solodit-aggregated-checklist.md`.
- Stored raw source (full descriptions/remediations/refs) at `tools/ref/solodit-checklist.json`.

## What we promoted into the front-line suite
Added **protocol-archetype playbooks** to `checklists/master-checklist.md` — the
highest-signal questions per archetype, each tagged with the source `SOL-*` ID:
- Vault/ERC-4626 (share inflation, donation, same-tx deposit/withdraw, 1-wei edge)
- AMM/Swap (slippage on-chain/last-step, deadline, callback caller check, FoT/rebasing)
- Lending (liquidation under stress/pause, self-liquidation, interest in LTV, same-tx
  lend+borrow, unrepayable positions)
- LSD (repricing sandwich, `_safeMint` reentrancy, arbitrary exchange rate, precision)
- Staking, Signatures (replay/malleability/ecrecover), Multi-chain/Cross-chain.

Added 3 new semgrep seed rules: `balanceof-self-for-accounting`, `ecrecover-result-unvalidated`,
`swap-without-min-out-or-deadline`.

## Important caveat surfaced
The Solodit checklist + our playbooks are **Solidity/EVM-centric**. Project scope now
includes **Solana (Rust/Anchor)** and **Sui/Move** (user decision 2026-06-01). Those
need their own ecosystem checklists — the EVM bug classes don't map 1:1.

## Next actions (backlog)
- [ ] **Solana checklist**: mine Anchor/Sealevel pitfalls — missing signer/owner checks,
      account confusion / type cosplay, missing `has_one`, PDA bump canonicalization,
      arbitrary CPI, integer overflow (no auto-checks pre-Anchor), rent/realloc.
- [ ] **Sui/Move checklist**: object ownership, ability model (key/store/copy/drop),
      shared-object consensus, capability leaks, `public entry` exposure.
- [ ] Mine 5–10 specific high-sev Code4rena reports → concrete coded PoC patterns.
- [ ] Cross-link each `master-checklist` archetype item to a Foundry invariant template.
- [ ] Deep-dive case studies still pending (Cetus/Balancer/Yearn) with real code.
