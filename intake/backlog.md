# Exploit recompilation backlog

Tracking sheet for the software-only exploit recompilation (see
[`../docs/research-plans/onyx-exploit-recompile.md`](../docs/research-plans/onyx-exploit-recompile.md)).
Onyx appends/updates rows; Claude flips them to `promoted` on review.

**Status legend:** `todo` → `drafting` → `review` (ready for Claude) → `promoted`
(merged to repo) · `rejected` (out of scope / dup, keep the row + reason).

**Priority:** P1 = high loss **and** a reusable code-bug class (oracle / logic /
precision / reentrancy / access-control / validation); P2 = reusable but smaller;
P3 = niche. Do P1 first.

| id | date | protocol | class | loss | source | priority | status |
|----|------|----------|-------|------|--------|----------|--------|
| _already in catalog — do NOT redo (dedup reference):_ |
| erc4626-inflation | recurring | ERC-4626 vaults | SC07/SC02 | — | docs/exploits | — | promoted |
| read-only-reentrancy | recurring | Curve-LP consumers | SC08 | — | docs/exploits | — | promoted |
| balancer-v2-rounding | 2025-11-03 | Balancer V2 | SC07 | $128M | docs/exploits | — | promoted |
| cashio-infinite-mint | 2022-03-23 | Cashio | SC05/SC02 | $52.8M | docs/exploits | — | promoted |
| cetus-amm-overflow | 2025-05-22 | Cetus | SC07/SC09 | $223M | docs/exploits | — | promoted |
| loopscale-oracle-spot-price | 2025-04-26 | Loopscale | SC03/SC02 | $5.8M | docs/exploits | — | promoted |
| loopscale-ratex-cpi | 2025-04-26 | Loopscale | SC03/SC05 | $5.8M | docs/exploits | — | promoted |
| mango-oracle-manipulation | 2022-10-11 | Mango | SC03/SC02 | $114M | docs/exploits | — | promoted |
| beanstalk-governance-flashloan | 2022-04-17 | Beanstalk | SC02/SC04 | $181M | docs/exploits | — | promoted |
| rhea-finance-slippage | 2026-04-16 | Rhea/Burrowland | SC02/SC07 | $18.4M | docs/exploits | — | promoted |
| _seed candidates — VERIFY date/loss/class against DeFiHackLabs + primary post-mortem before drafting:_ |
| euler-donation-liquidation-2023 | 2023-03 | Euler Finance | SC02 logic | ~$197M | DeFiHackLabs past/2023 | P1 | todo |
| curve-vyper-reentrancy-2023 | 2023-07 | Curve (Vyper) | SC08 reentrancy | ~$73M | DeFiHackLabs past/2023 | P1 | todo |
| kyberswap-tick-logic-2023 | 2023-11 | KyberSwap Elastic | SC02 logic/precision | ~$48M | DeFiHackLabs past/2023 | P1 | todo |
| wormhole-signature-verif-2022 | 2022-02 | Wormhole bridge | SC05/SC01 | ~$326M | DeFiHackLabs past/2022 | P1 | todo |
| nomad-init-2022 | 2022-08 | Nomad bridge | SC05/SC01 init | ~$190M | DeFiHackLabs past/2022 | P1 | todo |
| cream-reentrancy-2021 | 2021-08 | CREAM Finance | SC08 reentrancy | ~$18.8M | DeFiHackLabs past/2021 | P2 | todo |
| rari-fei-reentrancy-2022 | 2022-04 | Rari/Fei | SC08 reentrancy | ~$80M | DeFiHackLabs past/2022 | P1 | todo |
| penpie-reentrancy-2024 | 2024-09 | Penpie | SC08 reentrancy | ~$27M | DeFiHackLabs past/2024 | P1 | todo |
| platypus-logic-2023 | 2023-02 | Platypus Finance | SC02 logic | ~$8.5M | DeFiHackLabs past/2023 | P2 | todo |

> The seed list is a starting point, not the full set. **Step 1 of the plan is for
> Onyx to generate the complete software-only backlog from DeFiHackLabs** (filter out
> X-class/ops incidents, sort by loss, dedup against the catalog rows above) and append
> the rows here before drafting.

## Mined from DeFiHackLabs — distinct classes not yet in the catalog (2026-06-02)

Curated from the DeFiHackLabs incident set (691 incidents; class distribution:
business-logic 109, price-manipulation 74+, access-control 80+, reentrancy 42+,
precision/rounding ~24, signature/storage/randomness in the long tail). Filtered to
**software-only code bugs**, deduped against the 10 catalog entries + the seeds above, and
chosen for **distinct reusable detector value** — each row adds a *new* detector class, not
just another incident. Verify date/loss against the primary post-mortem before drafting.

| id | date | protocol (representative) | class — *new detector it adds* | loss | priority | status |
|----|------|---------------------------|--------------------------------|------|----------|--------|
| ctoken-empty-market-exchange-rate | 2023-04 | Hundred Finance / Sonne / Onyx | SC07 — *cToken/lending exchange-rate inflation via empty-market donation (distinct from erc4626)* | ~$7M+ | P1 | promoted |
| approval-drain-arbitrary-call | 2024-02 | Seneca / Socket / Sushi RouteProcessor2 | SC05/SC01 — *router executes an arbitrary call carrying users' token approvals → mass approval drain* (the 18-incident "arbitrary external call" class) | ~$6–33M ea | P1 | promoted |
| proxy-storage-collision | 2022-07 | Audius | SC-proxy — *upgradeable proxy storage-slot collision lets an init/governance var overwrite another* | ~$6M | P1 | promoted |
| signature-replay-malleability | recurring | permit / bridges / TCH | SC01 — *missing nonce/domain or ecrecover malleability → replayed/forged signatures* | varies | P1 | promoted |
| unprotected-privileged-fn | recurring | PAID Network / many | SC01 — *missing access control on a privileged init/mint/setter* (largest DHL class by count) | up to ~$180M | P1 | promoted |
| insecure-randomness | recurring | NFT mints / lotteries | SC09 — *predictable on-chain RNG (block vars / blockhash) gamed* | varies | P2 | promoted |
| weird-erc20-accounting | recurring | fee-on-transfer / rebasing tokens | SC-integration — *protocol assumes received == sent; fee-on-transfer/rebasing breaks accounting* | varies | P2 | promoted |
| incorrect-reward-accounting | recurring | MasterChef / staking forks | SC02 — *reward/debt math desync (double-claim, inflated pending)* | varies | P2 | promoted |
| unverified-flashloan-callback | recurring | lending forks | SC05 — *flash-loan/callback hook callable by a spoofed provider without verifying the caller* | varies | P2 | promoted |
| qubit-bridge-deposit-logic | 2022-01 | Qubit | SC02 — *bridge credits deposits for a zero/!-validated token address* | ~$80M | P2 | promoted (id `bridge-deposit-no-code-token`) |
| first-deposit-amm-skim | recurring | AMM pairs | SC07 — *empty-pool first-deposit / skim share manipulation (AMM-pair variant of inflation)* | varies | P3 | promoted |

> **How to consume this (the durable way — per the user's choice 2026-06-02):** do NOT
> copy DeFiHackLabs PoC code. For each row: study the primary post-mortem (+ the DHL
> fork-replay for reference), write `docs/exploits/<id>.md`, add a catalog entry with
> `root_cause` + `applies_when` + `variant_queries`, build our own minimal
> `Vulnerable<X>`+`Safe<X>`+test PoC, and link the DHL replay as `fork_poc`. Each new
> *class* (not each incident) is the unit of value — one strong representative per class
> beats ten near-duplicates.
