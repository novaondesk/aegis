# Research Log — 2026-06-02 — Rhea Finance Slippage Exploit

## Done
- Deep-dived Rhea Finance $18.4M exploit (April 2026, NEAR Protocol)
- Root cause: `get_token_out()` in Burrowland margin trading summed ALL `min_amount_out` values across multi-hop swap routes including intermediate hops, inflating the validated minimum by 4.1M×
- Secondary flaw: `on_open_trade_return()` credited whatever arrived without checking against validated minimum
- Attack: 123 fake tokens, 25 fake pools, 5 worker wallets in 10 seconds
- Created case study: `docs/exploits/rhea-finance-slippage-2026-04-16.md`
- Added catalog entry: `rhea-finance-slippage` in `catalog/exploits.yaml`
- Added checklist item: `SC02-SWAP-1` in `checklists/master-checklist.md`
- Added semgrep rule: `tools/semgrep/multi-hop-min-sum.yaml`
- Updated `docs/exploits/2026-recent-exploits.md` backlog

## Takeaways
- Multi-hop swap validation is a universal pattern — applies to EVM (Uniswap routers), Solana (Jupiter), Sui, and NEAR
- The bug was introduced in Burrowland V2 (July 2024), after the last audit (March 2022) — unaudited code paths are the #1 source of exploits
- Post-swap validation is as important as pre-swap validation — crediting whatever arrives without re-checking is a silent failure mode
- The attacker used Rhea's own ZcashFi infrastructure to launder $4M into shielded pools — ironic

## Next
- [ ] Ekubo approval-based exploit deep-dive ($1.4M, May 2026) — failed this run due to API key error
- [ ] Kelp DAO bridge exploit deep-dive ($292M, April 2026) — research complete, not yet written as case study (config vulnerability, less code-focused)
- [ ] Foundry PoC for multi-hop swap slippage inflation pattern
- [ ] Yearn yETH share-calc deep-dive (last remaining backlog item)
