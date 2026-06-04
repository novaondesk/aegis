---
title: Home
nav_order: 1
---

# Aegis
{: .fs-9 }

Exploit-catalog-driven smart contract security auditing — **find the bug, prove the fix.**
{: .fs-6 .fw-300 }

[Get started](getting-started){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-2 }
[View on GitHub ↗](https://github.com/novaondesk/aegis){: .btn .fs-5 .mb-4 .mb-md-0 }

---

Aegis evaluates a target contract or protocol against a curated catalog of **studied, real-world DeFi
exploits** — so you find vulnerabilities *and* prove the fix before an attacker does. Every studied
exploit becomes a structured **detector**; auditing a target means sweeping it against the whole
catalog, proving each hit with a runnable PoC, then shipping a fix proven by a `Safe<X>` PoC.

> The durable asset is the **catalog**, not any one scanner. Tools narrow the haystack; the catalog
> tells you exactly which known attacks to check, and a PoC tells you whether the target is actually
> vulnerable.

## What's inside

| | |
|---|---|
| **[The catalog](the-catalog)** | 34 detectors (29 with runnable PoCs) mined from real incidents + wargames — $292M Kelp, $181M Beanstalk, $128M Balancer, … |
| **[PoCs & detectors](pocs)** | A `Vulnerable<X>` + `Safe<X>` + exploit test per detector — the proof, not a vibe |
| **[Fork-simulation](fork-simulation)** | Exploit the *real deployed target* on a mainnet fork — 4 real incident replays |
| **[The Ethernaut wargame](wargame)** | Aegis solves OpenZeppelin's CTF **31/31** by the catalog sweep |
| **[How it works](how-it-works)** | The audit loop + the two agent skills (red `aegis-audit`, blue `aegis-defender`) |

## Proof it generalizes

The same detectors that catch real mainnet hacks also solve an independent third-party CTF:

| Ethernaut level | Detector | … and the matching mainnet replay |
|---|---|---|
| Delegation | `proxy-storage-collision` | Audius governance takeover ($1.08M) |
| Dex | `loopscale-oracle-spot-price` | Mango oracle manipulation ($114M) |
| Motorbike | `unprotected-privileged-fn` | DAO Maker unprotected init ($5.76M) |
| Reentrance | `cei-reentrancy` | The DAO class |
| CoinFlip | `insecure-randomness` | recurring NFT/lottery RNG |

---
{: .text-grey-dk-000 }
Defensive / responsible-disclosure use only. We evaluate in-scope bounty targets, public post-mortems,
or our own deployments — to get bugs fixed.
