# Aegis vs. Damn Vulnerable DeFi v4

Aegis run against [Damn Vulnerable DeFi v4](https://www.damnvulnerabledefi.xyz/) — the DeFi-focused
sibling of Ethernaut. Where the Ethernaut report showed many "general technique" levels, **DVD is the
real validation**: it stresses exactly the catalog's strongest classes (oracle manipulation,
flashloans, governance, upgrades, accounting), and the detectors mined from $100M+ hacks map straight
onto it. Each challenge is solved with the [`aegis-audit`](../skills/aegis-audit/SKILL.md) loop: RECON
the challenge → SWEEP the catalog → PROVE by filling in the challenge's `test_*` and passing
`_isSolved()`.

**Status: 14 / 18 solved** (all challenges that exercise a catalog detector class). The remaining 4
are intricate puzzle-mechanics (precision rounding, create2 address-mining, an L2→L1 bridge ordering
race, and a Curve read-only-reentrancy on a mainnet fork) — see the bottom.

## Validation — the catalog detectors that fired

| DVD challenge | Catalog detector | Real-world twin |
|---|---|---|
| **Truster** | [`approval-drain-arbitrary-call`](exploits/approval-drain-arbitrary-call-2024-02.md) | Socket Gateway |
| **Selfie** | [`beanstalk-governance-flashloan`](exploits/beanstalk-governance-flashloan-2022-04-17.md) | Beanstalk ($181M) |
| **Puppet / Puppet V2 / Puppet V3** | [`mango-oracle-manipulation`](exploits/mango-markets-oracle-manipulation.md) · [`loopscale-oracle-spot-price`](exploits/loopscale-oracle-2025-04.md) | Mango ($114M) / Loopscale |
| **Climber** | [`proxy-storage-collision`](exploits/proxy-storage-collision-2022-07.md) (upgrade/timelock) | Audius |
| **Unstoppable** | [`erc4626-inflation`](exploits/erc4626-inflation-attack.md) (donation → DoS) | recurring vault inflation |
| **Compromised** | oracle manipulation (spot/median) + info-exposure | Mango family |

That's the headline: **the same detectors that catch real mainnet hacks solve a DeFi CTF built
independently.** Puppet V3 was even solved over a **live mainnet fork** (the catalog + our
[fork-simulation harness](fork-simulation) in one flow).

## Full coverage (14 / 18)

| # | Challenge | Class | Solve | Catalog |
|---|-----------|-------|-------|---------|
| 1 | Unstoppable | SC02/SC07 | ✅ | `erc4626-inflation` (donation breaks `balanceOf==shares` → flashloan DoS) |
| 2 | Naive Receiver | SC01 | ✅ | meta-tx `_msgSender()` spoof via the forwarder (no exact entry) |
| 3 | Truster | SC05/SC01 | ✅ | **`approval-drain-arbitrary-call`** — `functionCall` → approve → drain |
| 4 | Side Entrance | SC02/SC04 | ✅ | flashloan callback re-deposits to pass the balance check |
| 5 | The Rewarder | SC02 | ✅ | claim-accounting: transfer every loop, bitmap marked once → repeat claim |
| 6 | Selfie | SC02/SC04 | ✅ | **`beanstalk-governance-flashloan`** — flashloan votes → `emergencyExit` |
| 7 | Compromised | SC03 | ✅ | leaked oracle keys (info-exposure) → median price manipulation |
| 8 | Puppet | SC03 | ✅ | **oracle spot-price** (Uniswap V1 reserve ratio) |
| 9 | Puppet V2 | SC03 | ✅ | **oracle spot-price** (Uniswap V2) |
| 10 | Puppet V3 | SC03 | ✅ | **oracle TWAP** (Uniswap V3, mainnet fork) |
| 11 | Free Rider | SC02 | ✅ | marketplace pays the buyer + checks total `msg.value` (flash-swap) |
| 12 | Backdoor | SC01 | ✅ | Gnosis Safe `setup` delegatecall → inject `approve` backdoor |
| 13 | Climber | SC01 | ✅ | **`proxy-storage-collision`/upgrade** — timelock CEI → UUPS upgrade drain |
| 15 | ABI Smuggling | SC05 | ✅ | calldata manipulation — permitted selector at the checked offset |
| 14 | Wallet Mining | SC01 | ⏳ | create2/deterministic-address mining + upgradeable authorizer |
| 16 | Shards | SC07 | ⏳ | fractional-NFT precision: `fill` divides by `totalShards`, `cancel` doesn't |
| 17 | Curvy Puppet | SC03/SC08 | ⏳ | Curve `get_virtual_price` read-only reentrancy (needs a mainnet fork) |
| 18 | Withdrawal | SC02 | ⏳ | L2→L1 bridge: operator proof-bypass + finalize-ordering race |

## Gaps surfaced (catalog to-do)

Consistent with the Ethernaut findings, a few solves needed general techniques the catalog doesn't yet
encode as detectors: **meta-transaction `_msgSender()` spoofing** (Naive Receiver), **claim/loop
accounting desync** (The Rewarder — adjacent to `incorrect-reward-accounting`), **calldata smuggling**
(ABI Smuggling — the Ethernaut Switch class), and **fractional/precision rounding** (Shards). These are
candidate new entries.

## The remaining 4 (intricate puzzle-mechanics)

These don't add catalog-detector coverage — they're CTF puzzles:
- **Shards** (SC07 precision): the cost/refund rounding asymmetry is identified; landing it needs the
  exact free-fill (`want` small enough that the cost rounds to 0, player holds 0 DVT) repeated to clear
  the threshold.
- **Wallet Mining**: brute-force a create2 salt so a Safe deploys at a pre-funded address + an
  upgradeable authorizer storage quirk.
- **Withdrawal**: as the granted operator (who bypasses the merkle proof), front-run the malicious
  withdrawal and restore the bridge balance within the delay window.
- **Curvy Puppet**: read-only reentrancy on Curve's `get_virtual_price` against a mainnet fork — the
  same class as our [`read-only-reentrancy`](exploits/read-only-reentrancy.md) entry, but heavy setup.

## Reproduce

```bash
git clone https://github.com/theredguild/damn-vulnerable-defi
cd damn-vulnerable-defi && git submodule update --init --recursive
cp -r /path/to/aegis/dvd/solutions/test/* test/
# Puppet V3 needs an archive RPC:
export MAINNET_FORKING_URL=<archive-rpc>
forge test
```

Solved test files (our `test_*` filled in, DVD's `setUp`/`_isSolved` unchanged) are in
[`dvd/solutions/`](https://github.com/novaondesk/aegis/tree/main/dvd/solutions). Level contracts are
DVD's (MIT, github.com/theredguild/damn-vulnerable-defi).
