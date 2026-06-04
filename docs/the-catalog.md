---
title: The catalog
nav_order: 4
---

# The exploit catalog
{: .no_toc }

[`catalog/exploits.yaml`](https://github.com/novaondesk/aegis/blob/main/catalog/exploits.yaml) is the single source of truth — the
machine-readable manifest the `aegis-audit` sweep loads. Each entry distills a **real** studied
exploit into a structured detector you can check against a target.
{: .fs-5 .fw-300 }

1. TOC
{:toc}

## Why a catalog (not a scanner)

Most catalog entries are **not** statically flaggable — they're business-logic, oracle, precision,
and access bugs that tools can't read intent for. The catalog encodes *what to check and why*, each
entry justified by a real incident with a loss attached. The durable asset is the catalog; tools just
narrow the haystack.

## Entry schema

Every entry is a detector with these fields:

| Field | Meaning |
|---|---|
| `id` | kebab-case unique id (matches the case study + PoC) |
| `class` | OWASP SC Top-10 (2026) ids + X-classes |
| `chains` | evm · solana · sui-move · … |
| `archetypes` | target shapes it applies to (scopes the sweep) |
| `root_cause` | one-line variant-analysis statement — the sweep's true/false-positive judge |
| `applies_when` | preconditions to check against the target's source (the more hold, the higher the rank) |
| `probes` | concrete ways to confirm (grep / semgrep / manual) |
| `variant_queries` | grep/semgrep family to hunt the bug across a target |
| `invariant` | the property that should hold; the exploit breaks it |
| `poc` / `poc_cmd` | runnable proof + how to run it |
| `fork_poc` | (optional) a real mainnet-fork replay |

## All 34 detectors

| # | Detector (`id`) | Class | Chains | Status |
|---|---|---|---|---|
| 1 | [`erc4626-inflation`](pocs#erc4626-inflation) | SC07/SC02 | evm | coded |
| 2 | [`read-only-reentrancy`](pocs#read-only-reentrancy) | SC08 | evm | coded |
| 3 | [`balancer-v2-rounding`](pocs#balancer-v2-rounding) | SC07 | evm/multi | coded |
| 4 | [`cashio-infinite-mint`](pocs#cashio-infinite-mint) | SC05/SC02 | solana | coded |
| 5 | [`cetus-amm-overflow`](pocs#cetus-amm-overflow) | SC07/SC09 | sui-move | coded |
| 6 | [`loopscale-oracle-spot-price`](pocs#loopscale-oracle-spot-price) | SC03/SC02 | solana | coded |
| 7 | [`loopscale-ratex-cpi`](pocs#loopscale-ratex-cpi) | SC03/SC02/SC05 | solana | coded |
| 8 | [`mango-oracle-manipulation`](pocs#mango-oracle-manipulation) | SC03/SC02 | solana | coded |
| 9 | [`beanstalk-governance-flashloan`](pocs#beanstalk-governance-flashloan) | SC02/SC04 | evm | coded |
| 10 | [`rhea-finance-slippage`](pocs#rhea-finance-slippage) | SC02/SC07 | near/multi | coded |
| 11 | [`trustedvolumes-access-control`](pocs#trustedvolumes-access-control) | SC02 | evm | coded |
| 12 | [`verus-bridge-merkle-forgery`](pocs#verus-bridge-merkle-forgery) | SC02 | evm/multi | coded |
| 13 | [`thorchain-tss-gg20-key-extraction`](pocs#thorchain-tss-gg20-key-extraction) | X04 | multi | studied |
| 14 | [`ekubo-callback-approval-drain`](pocs#ekubo-callback-approval-drain) | SC02/SC02-CB | evm | studied |
| 15 | [`kelp-dao-layerzero-dvn-1-1`](pocs#kelp-dao-layerzero-dvn-1-1) | X01/X01-BRIDGE | ethereum/multi-chain | coded |
| 16 | [`ctoken-empty-market-exchange-rate`](pocs#ctoken-empty-market-exchange-rate) | SC07/SC02 | evm | coded |
| 17 | [`approval-drain-arbitrary-call`](pocs#approval-drain-arbitrary-call) | SC05/SC01 | evm | coded |
| 18 | [`proxy-storage-collision`](pocs#proxy-storage-collision) | SC01 | evm | coded |
| 19 | [`signature-replay-malleability`](pocs#signature-replay-malleability) | SC01 | evm | coded |
| 20 | [`unprotected-privileged-fn`](pocs#unprotected-privileged-fn) | SC01 | evm | coded |
| 21 | [`insecure-randomness`](pocs#insecure-randomness) | SC09 | evm | coded |
| 22 | [`weird-erc20-accounting`](pocs#weird-erc20-accounting) | SC02 | evm | coded |
| 23 | [`incorrect-reward-accounting`](pocs#incorrect-reward-accounting) | SC02 | evm | coded |
| 24 | [`unverified-flashloan-callback`](pocs#unverified-flashloan-callback) | SC05/SC01 | evm | coded |
| 25 | [`bridge-deposit-no-code-token`](pocs#bridge-deposit-no-code-token) | SC02 | evm | coded |
| 26 | [`first-deposit-amm-skim`](pocs#first-deposit-amm-skim) | SC07 | evm | coded |
| 27 | [`cei-reentrancy`](pocs#cei-reentrancy) | SC08 | evm | coded |
| 28 | [`meta-tx-msgsender-spoof`](pocs#meta-tx-msgsender-spoof) | SC01 | evm | coded |
| 29 | [`calldata-abi-smuggling`](pocs#calldata-abi-smuggling) | SC05/SC01 | evm | coded |
| 30 | [`forced-ether-balance-assumption`](pocs#forced-ether-balance-assumption) | SC02 | evm | coded |
| 31 | [`dos-griefing-revert`](pocs#dos-griefing-revert) | SC10/SC02 | evm | coded |
| 32 | `yearn-yeth-solver-underflow` | SC02/SC07 | evm | studied |
| 33 | `transit-finance-legacy-approval-drain` | SC02 | evm/tron | studied |
| 34 | `hyperbridge-mmr-leaf-index` | SC02 | substrate/multi | studied |

> Entries 28–31 were mined from the **wargames** (DVD v4 Naive Receiver / ABI Smuggling, Ethernaut
> Force/King/Denial/Switch) — the loop working as intended: a level solved by a general technique
> becomes a catalog detector. Entries 32–34 are recent case studies (Yearn yETH solver underflow,
> Transit Finance legacy-approval drain, Hyperbridge MMR verifier) still in `studied` status — see
> their write-ups under [`docs/exploits/`](https://github.com/novaondesk/aegis/tree/main/docs/exploits).
>
> See **[PoCs](pocs)** for what each detector catches and its runnable proof. *(EVM model)* entries
> reproduce a non-EVM incident's broken invariant in Solidity so it runs in the Foundry harness.
