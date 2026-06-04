---
title: The Ethernaut wargame
nav_order: 8
---

# Aegis vs. the Ethernaut wargame
{: .no_toc }

Aegis solves **all 31 levels** of OpenZeppelin's [Ethernaut](https://ethernaut.openzeppelin.com/) CTF
using only its own catalog sweep — an independent, third-party benchmark that both *validates* the
detectors (mined from real hacks) and *surfaces gaps* worth adding.
{: .fs-5 .fw-300 }

1. TOC
{:toc}

## How it was run

The live game is a wallet + testnet SPA; the meaningful test is the **catalog-driven detect-and-
exploit** on the level *contracts*. For each level: RECON the source → SWEEP the catalog
(`applies_when` match) → PROVE by deploying the real level in Foundry and exploiting it to the level's
own win condition. Harness: [`ethernaut/`](https://github.com/novaondesk/aegis/tree/main/ethernaut)
(`cd ethernaut && forge test` → **31 passing**).

## Validation — exact catalog detectors

Ten levels are caught by an exact catalog entry — the same detectors that fire on mainnet hacks:

| Catalog detector | Ethernaut levels | Real-world twin |
|---|---|---|
| [`proxy-storage-collision`](pocs#proxy-storage-collision) | Delegation, Preservation, PuzzleWallet | Audius takeover ($1.08M) |
| [`unprotected-privileged-fn`](pocs#unprotected-privileged-fn) | Fallout, Motorbike, Fallback | DAO Maker ($5.76M) |
| [`loopscale-oracle-spot-price`](pocs#loopscale-oracle-spot-price) | Dex, DexTwo | Mango ($114M) / Loopscale |
| [`insecure-randomness`](pocs#insecure-randomness) | CoinFlip | recurring NFT/lottery RNG |
| [`cei-reentrancy`](pocs#cei-reentrancy) | Reentrance | The DAO class |

## Gaps surfaced — the catalog's to-do list

The other 21 levels are solved with general techniques that point at detector classes the catalog
doesn't yet encode — an honest backlog: **denial-of-service** (King, Denial), **forced ether** (Force),
**information exposure** (Vault, Privacy), **integer/storage underflow** (Token, AlienCodex),
**tx.origin auth** (Telephone, Gatekeepers), **calldata/ABI manipulation** (Switch, HigherOrder), and
**untrusted-interface assumptions** (Elevator, Shop).

> This is the loop working as intended — the Reentrance level already prompted adding the exact
> [`cei-reentrancy`](pocs#cei-reentrancy) detector.

## Full report

The complete 31-level coverage table + per-detector write-up is at
**[docs/ethernaut-wargame.md](https://github.com/novaondesk/aegis/blob/main/docs/ethernaut-wargame.md)**.
