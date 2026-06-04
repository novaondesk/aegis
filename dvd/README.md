# dvd/ — Aegis vs. Damn Vulnerable DeFi v4

Testing Aegis on [Damn Vulnerable DeFi v4](https://www.damnvulnerabledefi.xyz/) — the DeFi-focused
sibling of Ethernaut. Unlike Ethernaut (many "technique" levels), **DVD stresses exactly the catalog's
strongest classes**: oracle manipulation, flashloans, governance, reentrancy, proxies, merkle/bridge.
Each challenge is solved with the [`aegis-audit`](../skills/aegis-audit/SKILL.md) loop: RECON the
challenge → SWEEP the catalog → PROVE by filling in the challenge's `test_*` and passing `_isSolved()`.

## Status

| # | Challenge | Catalog detector | Status |
|---|-----------|------------------|--------|
| 1 | Unstoppable | `erc4626-inflation` (donation → DoS) | ✅ |
| 2 | Naive Receiver | SC01 meta-tx `_msgSender` spoof | ✅ |
| 3 | Truster | **`approval-drain-arbitrary-call`** | ✅ |
| 4 | Side Entrance | SC02/SC04 flashloan re-deposit | ✅ |
| 5 | The Rewarder | SC02 claim-accounting (repeat claim) | ✅ |
| 6 | Selfie | **`beanstalk-governance-flashloan`** | ✅ |
| 7 | Compromised | info-exposure → oracle manipulation | ✅ |
| 8 | Puppet | **`mango-oracle-manipulation` / `loopscale-oracle-spot-price`** | ✅ |
| 9 | Puppet V2 | **oracle spot-price manipulation** | ✅ |
| 10 | Puppet V3 | **oracle (V3 TWAP) manipulation** (mainnet fork) | ✅ |
| 11 | Free Rider | **SC02 logic** (pay-the-buyer + total msg.value) | ✅ |
| 12 | Backdoor | **SC01 init-delegatecall backdoor** (Safe setup) | ✅ |
| 13 | Climber | **`proxy-storage-collision`/upgrade** (timelock CEI) | ✅ |
| 14 | Wallet Mining | **SC01 + slot-0 storage collision** (create2 salt-mine, single-tx) | ✅ |
| 15 | ABI Smuggling | **calldata manipulation** (Switch family) | ✅ |
| 16 | Shards | SC07 precision | ✅ |
| 17 | Curvy Puppet | **`read-only-reentrancy`** (Curve `get_virtual_price`, mainnet fork) | ✅ |
| 18 | Withdrawal | `verus-bridge-merkle-forgery` | ✅ |

**18 / 18 solved** — the entire DVD v4 set falls to the catalog-driven loop, including the two hardest:
Wallet Mining's single-tx storage-collision puzzle and Curvy Puppet's read-only-reentrancy liquidation
over a live mainnet fork. Full write-up: [`../docs/dvd-wargame.md`](../docs/dvd-wargame.md).

## How to run

DVD v4 has heavy dependencies (Uniswap v2/v3, Safe, permit2, solady/solmate) installed as git
submodules, so it isn't vendored here. To reproduce:

```bash
git clone https://github.com/theredguild/damn-vulnerable-defi
cd damn-vulnerable-defi
git submodule update --init --recursive
# drop our solved test files over the originals:
cp -r /path/to/aegis/dvd/solutions/test/* test/
forge test
```

Our solutions live in [`solutions/test/`](solutions/) — the original DVD challenge `test/*.t.sol`
files with the `test_*` solution function filled in (and any attacker helper contract appended). The
challenge contracts and `setUp`/`_isSolved` are DVD's, unchanged (MIT,
github.com/theredguild/damn-vulnerable-defi).
