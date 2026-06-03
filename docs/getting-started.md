---
title: Getting started
nav_order: 2
---

# Getting started
{: .no_toc }

1. TOC
{:toc}

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (`forge`) — the PoC + simulation harness.
- For [fork-simulation](fork-simulation): an **archive** RPC endpoint (to pin historical blocks).
- Optional: `slither`, `semgrep` to accelerate the sweep's static probes.

## Clone

```bash
git clone https://github.com/novaondesk/aegis
cd aegis
```

## Run the model PoCs

The catalog's runnable proofs (`Vulnerable<X>` + `Safe<X>` + exploit test):

```bash
cd poc
forge install foundry-rs/forge-std   # once, lib/ is gitignored
forge test -vv
```

Run one detector's PoC (each catalog entry's `poc_cmd`):

```bash
forge test --match-contract InflationAttack -vv
```

## Run the fork-simulation replays

Exploit real deployed contracts on a mainnet fork (see **[Fork-simulation](fork-simulation)**):

```bash
cd sim
cp .env.example .env          # set ETH_RPC_URL to an archive endpoint
set -a; source .env; set +a
forge test -vvv
```

## Run the Ethernaut wargame

Aegis solving the CTF locally (see **[The wargame](wargame)**):

```bash
cd ethernaut
forge test -vv
```

## Use it as agent skills

Aegis ships as two composable [Agent Skills](https://github.com/novaondesk/aegis/tree/main/skills):

- **`aegis-audit`** (red team) — recon & scope → catalog sweep → engines → PoC → scored report.
- **`aegis-defender`** (blue team) — turns findings into fixes proven by a `Safe<X>` PoC + a release-gate.

Register the repo's `skills/` directory in place (so the `../../catalog` links resolve), then ask to
*"audit this contract"* or *"remediate these findings"*. See **[How it works](how-it-works)**.
