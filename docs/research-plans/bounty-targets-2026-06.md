# Active Bug Bounty Targets — June 2026

Scouted from Immunefi and HackenProof. Focus on programs with Base/L2 and Solana
coverage, TVL > $10M, and bounties > $50K.

## Tier 1: High-Value (Max Bounty > $1M)

| # | Protocol | Platform | Max Bounty | Chain(s) | TVL | Notes |
|---|----------|----------|-----------|----------|-----|-------|
| 1 | Uniswap v4 | Immunefi | $15.5M | Multi (Base, Unichain, etc.) | $5B+ | Largest active bounty. v4 hook architecture is novel attack surface. |
| 2 | LayerZero | Immunefi | $15M | Multi-chain (30+) | Billions | Cross-chain messaging — same class as Kelp DAO $292M exploit. DVN configs in scope. |
| 3 | Sky (MakerDAO) | Immunefi | $10M | Ethereum + L2s | $8B+ | Core stablecoin + vault + oracle infra. $1M/month payout cap for large bounties. |
| 4 | Wormhole | Immunefi | $5M | Multi (incl. Solana) | Billions | Cross-chain bridge — highest single payout was $10M to satya0x. |
| 5 | Optimism | Immunefi | $2M | OP Stack / Base | $5B+ | Covers OP Stack core, bridge, Cannon fault proof, Superchain interop. Base is built on OP Stack. |
| 6 | Lido | Immunefi | $2M | Ethereum | $14B+ | Liquid staking, wstETH bridge contracts, oracle infra, governance. |
| 7 | Kamino Finance | Immunefi | $1.5M | **Solana** | $2B+ | Solana's largest bounty. Rust programs — lending, liquidity vaults, multiply strategies. |
| 8 | Aave v3 | Immunefi | $1M | Multi (incl. Base, Arbitrum) | $20B+ | All active liquidity pool instances across 12+ networks. |

## Tier 2: Mid-Range ($100K–$1M)

| # | Protocol | Platform | Max Bounty | Chain(s) | TVL | Notes |
|---|----------|----------|-----------|----------|-----|-------|
| 9 | 1inch Network | HackenProof | $500K per component | Multi (incl. Base) | High volume | 5 separate programs: smart contracts, wallet, API, dApp, infrastructure. |
| 10 | Marinade Finance | Immunefi | $250K | **Solana** | $150M+ | Liquid staking, mSOL, delegation strategies. Rust/Solana-native. |

## Priority Analysis for Aegis

**Base/L2 targets** (where our EVM catalog applies directly):
- Aave v3 on Base — lending market vulnerabilities (oracle, precision, flash-loan)
- Optimism/OP Stack — bridge + fault proof system
- Uniswap v4 hooks — novel hook architecture = unexplored attack surface
- 1inch Fusion+ — aggregator + limit order logic

**Solana targets** (where our Solana checklist applies):
- Kamino Finance — $1.5M bounty, lending/liquidity vaults in Rust/Anchor
- Marinade Finance — liquid staking on Solana
- Wormhole — Guardian contracts (Rust)

**Cross-chain targets** (bridge/config class — our fastest-growing case study category):
- LayerZero — DVN configuration, endpoint contracts (cf. Kelp DAO $292M case study)
- Wormhole — Guardian set, message verification

## Recommended Next Steps

1. **Kamino Finance** — Largest Solana bounty ($1.5M), our Solana checklist has 31 items
   that map directly. Review Rust source for arithmetic overflow, CPI validation,
   oracle manipulation patterns we've cataloged.
2. **Aave v3 on Base** — $1M bounty, our EVM catalog has 30 case studies covering
   lending market patterns (oracle, precision, flash-loan, reentrancy).
3. **LayerZero OApps** — The Kelp DAO case study revealed 47% of OApps use 1/1 DVN
   configs. Bounty covers the messaging layer itself ($15M max).

## Sources
- https://immunefi.com/bounty/
- https://hackenproof.com/
- Immunefi has paid $115M+ historically across all programs
- Web3 bug bounty market exceeds $162M total available rewards
