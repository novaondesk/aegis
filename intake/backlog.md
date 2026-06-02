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
| _seed candidates — VERIFY date/loss/class against DeFiHackLabs + primary post-mortem before drafting:_ |
| euler-donation-liquidation-2023 | 2023-03 | Euler Finance | SC02 logic | ~$197M | DeFiHackLabs past/2023 | P1 | todo |
| curve-vyper-reentrancy-2023 | 2023-07 | Curve (Vyper) | SC08 reentrancy | ~$73M | DeFiHackLabs past/2023 | P1 | todo |
| kyberswap-tick-logic-2023 | 2023-11 | KyberSwap Elastic | SC02 logic/precision | ~$48M | DeFiHackLabs past/2023 | P1 | todo |
| wormhole-signature-verif-2022 | 2022-02 | Wormhole bridge | SC05/SC01 | ~$326M | DeFiHackLabs past/2022 | P1 | todo |
| nomad-init-2022 | 2022-08 | Nomad bridge | SC05/SC01 init | ~$190M | DeFiHackLabs past/2022 | P1 | todo |
| beanstalk-flashloan-gov-2022 | 2022-04 | Beanstalk | SC04 flash-loan | ~$181M | DeFiHackLabs past/2022 | P2 | todo |
| cream-reentrancy-2021 | 2021-08 | CREAM Finance | SC08 reentrancy | ~$18.8M | DeFiHackLabs past/2021 | P2 | todo |
| rari-fei-reentrancy-2022 | 2022-04 | Rari/Fei | SC08 reentrancy | ~$80M | DeFiHackLabs past/2022 | P1 | todo |
| penpie-reentrancy-2024 | 2024-09 | Penpie | SC08 reentrancy | ~$27M | DeFiHackLabs past/2024 | P1 | todo |
| platypus-logic-2023 | 2023-02 | Platypus Finance | SC02 logic | ~$8.5M | DeFiHackLabs past/2023 | P2 | todo |

> The seed list is a starting point, not the full set. **Step 1 of the plan is for
> Onyx to generate the complete software-only backlog from DeFiHackLabs** (filter out
> X-class/ops incidents, sort by loss, dedup against the catalog rows above) and append
> the rows here before drafting.
