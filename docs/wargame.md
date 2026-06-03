---
title: The Ethernaut wargame
nav_order: 8
---

# Aegis vs. the Ethernaut wargame
{: .no_toc }

Aegis solves OpenZeppelin's [Ethernaut](https://ethernaut.openzeppelin.com/) CTF **5/5** using only
its own catalog sweep — an independent, third-party benchmark that the same detectors (mined from
real hacks) map onto and solve.
{: .fs-5 .fw-300 }

1. TOC
{:toc}

## How it was run

The live game is a wallet + testnet SPA; the meaningful test is the **catalog-driven detect-and-
exploit** on the level *contracts*. For each level: RECON the source → SWEEP the catalog
(`applies_when` match) → PROVE by deploying the real level in Foundry and exploiting it to the level's
own win condition (`validateInstance`). Harness: [`ethernaut/`](https://github.com/novaondesk/aegis/tree/main/ethernaut)
(`cd ethernaut && forge test`).

## Results (5 / 5)

| Level | Class | Catalog detector | Proof |
|---|---|---|---|
| #3 CoinFlip | SC09 | [`insecure-randomness`](pocs#insecure-randomness) | [test](https://github.com/novaondesk/aegis/blob/main/ethernaut/test/CoinFlip.t.sol) |
| #6 Delegation | SC01 | [`proxy-storage-collision`](pocs#proxy-storage-collision) | [test](https://github.com/novaondesk/aegis/blob/main/ethernaut/test/Delegation.t.sol) |
| #10 Reentrance | SC08 | [`cei-reentrancy`](pocs#cei-reentrancy) | [test](https://github.com/novaondesk/aegis/blob/main/ethernaut/test/Reentrance.t.sol) |
| #22 Dex | SC03 | [`loopscale-oracle-spot-price`](pocs#loopscale-oracle-spot-price) | [test](https://github.com/novaondesk/aegis/blob/main/ethernaut/test/Dex.t.sol) |
| #25 Motorbike | SC01 | [`unprotected-privileged-fn`](pocs#unprotected-privileged-fn) | [test](https://github.com/novaondesk/aegis/blob/main/ethernaut/test/Motorbike.t.sol) |

## The same detectors span CTF and mainnet

- **Delegation** ↔ the Audius **$1.08M** [fork replay](fork-simulation) (`proxy-storage-collision`).
- **Dex** ↔ the Mango **$114M** / Loopscale entries (spot-price manipulation).
- **Motorbike** ↔ the DAO Maker **$5.76M** [fork replay](fork-simulation) (`unprotected-privileged-fn`).

The Reentrance level even **grew the catalog**: it initially mapped only to the SC08 family, so a
dedicated [`cei-reentrancy`](pocs#cei-reentrancy) detector was added — the benchmark feeding the
catalog is the loop working as intended.

## Full report

The per-level write-up — each matched detector, the exact `applies_when` signals that held, the root
cause, and the proof — is at
**[docs/ethernaut-wargame.md](https://github.com/novaondesk/aegis/blob/main/docs/ethernaut-wargame.md)**.
