# Research Log — 2026-06-03 — Yearn yETH Solver Deep-Dive

## Session: Autonomous cron run (aegis-research)

### What was done
- Completed Yearn yETH share-calc/solver exploit case study ($9M, November 30, 2025)
- Last remaining backlog item from web3isgoinggreat research queue
- Researched via Yearn's official disclosure (github.com/yearn/yearn-security) and Verichains technical breakdown

### Exploit Summary
- **Root cause:** Three compounding failures — (1) Newton-Raphson solver divergence under extreme imbalanced deposits drove product term Π to 0, (2) `unsafe_sub` in `_calc_supply` allowed uint256 underflow instead of reverting, (3) bootstrap initialization path was re-enterable after pool emptying
- **Attack vector:** Three-phase exploit — collapse invariant → drain via POL reconciliation → infinite mint via re-initialization
- **Impact:** $9M in LSTs drained (wstETH, rETH, cbETH, apxETH, sfrxETH, ETHx, mETH, wOETH + 298 WETH from Curve)
- **Key evidence:** Single transaction (block 23,914,086), 235 septillion LP tokens minted from 16 wei deposit, ~$3M laundered via Tornado Cash, ~$2.4M recovered

### Four-Place Update
1. ✅ **Case study:** `docs/exploits/yearn-yeth-solver-underflow-2025-11-30.md`
2. ✅ **Catalog entry:** `yearn-yeth-solver-underflow` in `catalog/exploits.yaml` — class SC07/SC02, chains evm, archetypes stableswap-pool/weighted-amm/iterative-solver/pol-reconciliation
3. ✅ **Checklist:** Three new items:
   - SC02-SOLVER-1: iterative solver domain validation + divergence detection
   - SC02-REINIT-1: bootstrap path re-enterability after production use
   - SC02-POL-1: POL reconciliation cost offloading
   - SC07-UNSAFE-1: unsafe_sub/unchecked in invariant-critical paths
4. ✅ **Detection artifact:** Catalog entry includes probes (grep for `_calc_supply`, `unsafe_sub`, `prev_supply == 0`, `pow_up`, `packed_vbs`), variant queries, and invariant template for solver domain checking

### Key Takeaways
- **Iterative solvers are high-value attack surfaces.** Newton-Raphson and fixed-point iteration solvers in AMMs (stableswap, weighted pools) have mathematical domains that must be enforced on-chain. When the solver is pushed outside its convergence regime by adversarial inputs, it can produce nonsensical outputs that the protocol accepts.
- **`unsafe_math` in invariant-critical code is a red flag.** The `unsafe_sub(A*Σ, D*Π)` in `_calc_supply` was the final nail — it turned a domain violation into a catastrophic mint instead of a revert. Checked arithmetic in invariant calculations is a must.
- **Re-initialization paths are exploit primitives.** Any bootstrap/initialization branch that can be re-entered after deployment is a potential second-chance exploit. The `prev_supply == 0` check was designed for first-deposit math, but an attacker who can drain the pool can reach it.
- **POL reconciliation is a trust boundary.** The protocol's assumption that `D` changes only reflect legitimate yield/slashing events was wrong. Adversarial manipulation of `D` turns the POL burn mechanism into a cost-offloading attack.
- **Legacy code is the real risk.** The yETH stableswap was a custom product separate from Yearn's V2/V3 vaults. Legacy/unmaintained contracts with real TVL are time bombs.

### Next Steps
- [ ] Create Foundry PoC for TrustedVolumes access control pattern
- [ ] Create Foundry PoC for governance flash-loan attack pattern
- [ ] Create Foundry PoC for multi-hop swap slippage inflation pattern
- [ ] Target scouting: active bug bounty programs on Immunefi/HackenProof
- [ ] Add semgrep rules for governance real-time voting power reads
- [ ] Add semgrep rule for public setter without access control modifier
- [ ] Stand up Solana-specific PoC harness (Anchor test framework)
- [ ] Stand up Sui/Move-specific PoC harness
