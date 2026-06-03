---
title: Fork-simulation
nav_order: 6
---

# Fork-simulation
{: .no_toc }

Prove findings against **forked real state** — the real deployed target + its live dependencies
(tokens, oracles, pools, even other users' standing approvals), not a hand-built model. This is the
DeFiHackLabs methodology and the `PROVE` phase for deployed targets.
{: .fs-5 .fw-300 }

1. TOC
{:toc}

## Why it's cleaner than it sounds

With a fork you **don't redeploy the target or its dependencies** — they already exist on the fork at
their real addresses with real storage and liquidity. You deploy only your **attacker contract**, then
drive an exploit. Cheatcodes cover setup: `vm.createSelectFork(rpc, block)` pins a block,
`vm.prank` acts as any address, `deal` funds the attacker with real tokens. Real reserves make
oracle/AMM/economic exploits testable *for real*.

A finding is confirmed when the catalog entry's **invariant breaks** and the **attacker ends with
profit**, on the forked target.

## The 4 real incident replays

All pass against Ethereum mainnet state at the pre-hack block ([`sim/`](https://github.com/novaondesk/aegis/tree/main/sim)):

| Incident | Detector | Result on the fork |
|---|---|---|
| [Socket Gateway](https://github.com/novaondesk/aegis/blob/main/sim/test/SocketApprovalDrain_2024_01.t.sol) (2024-01) | `approval-drain-arbitrary-call` | one call drains a real victim's **~656k USDC** via their standing approval |
| [Audius](https://github.com/novaondesk/aegis/blob/main/sim/test/AudiusGovTakeover_2022_07.t.sol) (2022-07) | `proxy-storage-collision` | seizes the real governance proxies, drains **~18.56M AUDIO** (~$1.08M) |
| [DAO Maker](https://github.com/novaondesk/aegis/blob/main/sim/test/DaoMakerInitDrain_2021_09.t.sol) (2021-09) | `unprotected-privileged-fn` | unprotected `init` → `emergencyExit` drains **5.76M DERC** |
| [Beanstalk](https://github.com/novaondesk/aegis/blob/main/sim/test/BeanstalkGovFlashloan_2022_04.t.sol) (2022-04) | `beanstalk-governance-flashloan` | flash-loans **~$1B** (Aave) → governance drain → **~$42M USDC** profit |

The Beanstalk replay drives Aave v2 + Curve (3pool + factory metapool) + the live Beanstalk diamond
— a full multi-protocol flashloan exploit, all on the fork.

## Run

```bash
cd sim
cp .env.example .env          # ETH_RPC_URL = an archive endpoint (to pin historical blocks)
set -a; source .env; set +a
forge test -vvv
```

## Scope

Forking is local — no funds move, nothing is broadcast — so it's safe to test even before
disclosure. Still: only simulate against in-scope bounty targets, your own deploys, or public
post-mortems. **Never broadcast an exploit transaction to a live network.**
