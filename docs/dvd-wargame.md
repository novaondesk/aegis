# Aegis vs. Damn Vulnerable DeFi v4

Aegis run against [Damn Vulnerable DeFi v4](https://www.damnvulnerabledefi.xyz/) — the DeFi-focused
sibling of Ethernaut. Where the Ethernaut report had many "general technique" levels, **DVD is the
real validation**: it stresses the catalog's strongest classes (oracle manipulation, flashloans,
governance, upgrades, accounting), and the detectors mined from $100M+ hacks map straight onto it.
Each challenge is solved with the [`aegis-audit`](../skills/aegis-audit/SKILL.md) loop — RECON the
challenge → SWEEP the catalog → PROVE by filling in `test_*` and passing `_isSolved()`.

**Status: 18 / 18 solved.** Every challenge in DVD v4 falls to the catalog-driven loop, including the
two hardest — Wallet Mining (create2 address-mining + a slot-0 storage-collision re-init, all in one
player tx) and Curvy Puppet (Curve `get_virtual_price` read-only reentrancy liquidation over a live
mainnet fork). Neither adds a *new* catalog class: Curvy Puppet *is* our existing `read-only-reentrancy`
detector, and Wallet Mining is SC01 access-control + a deterministic-address puzzle.

## The catalog detectors that fired (the headline)

The same detectors that catch real mainnet hacks solved a DeFi CTF built independently:

| DVD challenge | Catalog detector | Real-world twin |
|---|---|---|
| **Truster** | `approval-drain-arbitrary-call` | Socket Gateway |
| **Selfie** | `beanstalk-governance-flashloan` | Beanstalk ($181M) |
| **Puppet / V2 / V3** | `mango-oracle-manipulation` · `loopscale-oracle-spot-price` | Mango ($114M) / Loopscale |
| **Climber** | `proxy-storage-collision` (upgrade/timelock) | Audius |
| **Unstoppable** | `erc4626-inflation` (donation → DoS) | recurring vault inflation |
| **Compromised** | oracle manipulation + info-exposure | Mango family |
| **Withdrawal** | bridge message-verification (`verus-bridge-merkle-forgery` family) | Verus / Nomad |

Puppet V3 and Curvy Puppet run over a **live mainnet fork** (real Curve/Lido/Aave) — catalog + our
[fork-simulation harness](fork-simulation) in one flow.

## How each was solved (18 / 18)

| # | Challenge | Class | How Aegis solved it |
|---|-----------|-------|---------------------|
| 1 | Unstoppable | SC02/SC07 | ✅ `erc4626-inflation`: donate 1 token directly → `balanceOf != totalShares` → `flashLoan` reverts forever → monitor pauses it |
| 2 | Naive Receiver | SC01 | ✅ 10× fee-loans drain the receiver; then a `multicall` sub-call spoofs `_msgSender()==feeReceiver` to `withdraw` the pool — one signed forwarder request |
| 3 | Truster | SC05/SC01 | ✅ `approval-drain-arbitrary-call`: `flashLoan(0,…,token,approve(attacker,all))` then `transferFrom` (one tx) |
| 4 | Side Entrance | SC02/SC04 | ✅ flash-loan, the `execute` callback `deposit`s the ETH back (passes the balance check) crediting us, then `withdraw` |
| 5 | The Rewarder | SC02 | ✅ `claimRewards` transfers every loop but marks the bitmap once → submit the player's own valid proof N times |
| 6 | Selfie | SC02/SC04 | ✅ `beanstalk-governance-flashloan`: flash-loan the votes token → `delegate` → queue `emergencyExit` → execute |
| 7 | Compromised | SC03 | ✅ decode the leaked HTTP bytes → 2 oracle keys → set median price ~0, buy NFT, set high, sell, drain, restore |
| 8 | Puppet | SC03 | ✅ oracle spot-price: dump tokens to crash the Uniswap V1 reserve ratio, borrow the pool for tiny ETH |
| 9 | Puppet V2 | SC03 | ✅ same on Uniswap V2: swap to crash the price, wrap ETH, borrow the pool |
| 10 | Puppet V3 | SC03 | ✅ swap to move the V3 spot, `vm.warp(114s)` to shift the 10-min TWAP, borrow — over a **mainnet fork** |
| 11 | Free Rider | SC02 | ✅ flash-swap WETH; `buyMany` pays the *new owner* (buyer) and checks total `msg.value` → buy all 6 for one price; claim the bounty |
| 12 | Backdoor | SC01 | ✅ Gnosis Safe `setup`'s `to`/`data` delegatecall → inject `approve(attacker)` per beneficiary wallet, then drain the payouts (one tx) |
| 13 | Climber | SC01 | ✅ `proxy-storage-collision`/upgrade: timelock runs actions before the scheduled-check → grant role + zero delay + transfer vault + self-schedule, then UUPS-upgrade to a sweeper |
| 15 | ABI Smuggling | SC05 | ✅ calldata manipulation: put the permitted `withdraw` selector at the checked offset while `actionData` is `sweepFunds` |
| 16 | Shards | SC07 | ✅ precision: `fill` cost rounds to 0 for tiny `want` (free), `cancel` refunds `want*rate/1e6` (no `/totalShards`) → free fill seeds DVT, a sized fill drains the marketplace |
| 18 | Withdrawal | SC02 | ✅ `TokenBridge` sender-check is inverted + operator bypasses the merkle proof → drain to underflow the malicious withdrawal, pre-fail its `messageId`, refill; legit 3 pay out, #2 blocked |
| 14 | Wallet Mining | SC01 | ✅ `AuthorizerUpgradeable.needsInit` (slot 0) collides with `TransparentProxy.upgrader` (slot 0) → after setup slot 0 holds the non-zero upgrader, so `init()` is callable **again** → authorize our contract for the deposit address; brute-force the Safe salt nonce (**= 13**) to land the proxy on `USER_DEPOSIT_ADDRESS`; `drop()` deploys it + pays the reward; drain the 20M DVT with the user's **off-chain** Safe signature (user sends no tx); forward the reward to the ward — all in the attacker's constructor, the player's **single** transaction |
| 17 | Curvy Puppet | SC03/SC08 | ✅ `read-only-reentrancy`: the lender prices the LP as `oracle(ETH)·get_virtual_price()`, which is **unguarded** during `remove_liquidity` (LP burned + ETH sent before stETH) → flash-loan 80k ETH + 220k stETH (Aave), balloon the Curve stETH/ETH pool, then in the ETH callback **vp spikes to ~4.3×** so all 3 positions are underwater → liquidate all three in one reentrant sweep; same-asset repay, treasury's 200 WETH buffer absorbs premiums + Curve fee. **Live mainnet fork @ 20190356** |

## Gaps surfaced → catalog to-do

Several solves needed general techniques the catalog didn't yet encode as detectors. The strongest
ones were promoted to catalog entries this round (✅):

- ✅ **Meta-transaction `_msgSender()` spoofing** (Naive Receiver) → [`meta-tx-msgsender-spoof`](pocs#meta-tx-msgsender-spoof).
- ✅ **Calldata / ABI smuggling** (ABI Smuggling; Ethernaut Switch/HigherOrder) → [`calldata-abi-smuggling`](pocs#calldata-abi-smuggling).
- ✅ **Forced-ether / DoS** (from Ethernaut Force/King/Denial) → [`forced-ether-balance-assumption`](pocs#forced-ether-balance-assumption) + [`dos-griefing-revert`](pocs#dos-griefing-revert).
- **Claim/loop accounting desync** (The Rewarder) — covered by the adjacent [`incorrect-reward-accounting`](pocs#incorrect-reward-accounting) detector.
- **Fractional / precision rounding asymmetry** (Shards) — paired fill/refund math. *(to-do: a generic precision-asymmetry detector)*
- **Inverted / missing sender authorization on bridge message execution** (Withdrawal) — folded into [`verus-bridge-merkle-forgery`](pocs#verus-bridge-merkle-forgery)'s family.
- **Flash-loan re-deposit / same-asset accounting** (Side Entrance). *(to-do)*

## The two hardest, in detail

- **Wallet Mining (single-tx constraint).** `_isSolved` requires `vm.getNonce(player) == 1`, so the
  whole exploit must fit in **one** player transaction — we do it inside an attacker contract's
  constructor (the deploy *is* the one tx). The bug is a storage-slot collision: `AuthorizerUpgradeable`
  keeps `needsInit` at slot 0, but it runs behind a `TransparentProxy` whose own `upgrader` is **also**
  slot 0. `setUpgrader(upgrader)` therefore leaves slot 0 non-zero, so `needsInit != 0` and `init()` can
  be replayed — we re-authorize our attacker for the deposit address. We then brute-force the Safe
  `saltNonce` (**13**) so `createProxyWithNonce` lands the proxy exactly on the pre-funded
  `USER_DEPOSIT_ADDRESS`, call `drop()` to deploy it and collect the reward, and sweep the 20M DVT using
  the user's **off-chain** EIP-712 Safe signature (the user never transacts). Solution:
  [`dvd/solutions/test/wallet-mining/`](https://github.com/novaondesk/aegis/tree/main/dvd/solutions/test/wallet-mining).
- **Curvy Puppet (read-only reentrancy over a live fork).** Same class as our
  [`read-only-reentrancy`](exploits/read-only-reentrancy.md) detector (also validated by Ethernaut #10 /
  `cei-reentrancy`). The lender prices the borrow asset (Curve stETH/ETH LP) as
  `oracle(ETH) · curvePool.get_virtual_price()`, and `get_virtual_price()` is **not** behind the pool's
  reentrancy lock. `remove_liquidity` burns the LP and pays out ETH (coin 0) *before* stETH (coin 1), so
  mid-callback the invariant `D` is taken over a still-full stETH balance against an already-reduced
  supply → the virtual price spikes. We flash-loan **80k ETH + 220k stETH from Aave**, balloon the pool,
  and in the ETH callback (vp ≈ **4.3×**, measured empirically against the fork) every position is
  underwater — we liquidate all three in one sweep. Funds are repaid same-asset (wstETH unwrap/wrap +
  Lido `submit` to true up the stETH leg); the treasury's 200 WETH buffer absorbs the Aave premiums and
  the small Curve fee. Runs on a **mainnet fork @ block 20190356**. Solution:
  [`dvd/solutions/test/curvy-puppet/`](https://github.com/novaondesk/aegis/tree/main/dvd/solutions/test/curvy-puppet).

## Reproduce

```bash
git clone https://github.com/theredguild/damn-vulnerable-defi
cd damn-vulnerable-defi && git submodule update --init --recursive
cp -r /path/to/aegis/dvd/solutions/test/* test/
export MAINNET_FORKING_URL=<archive-rpc>   # Puppet V3
forge test
```

Solved test files (our `test_*` filled in; DVD's `setUp`/`_isSolved` untouched) are in
[`dvd/solutions/`](https://github.com/novaondesk/aegis/tree/main/dvd/solutions). Level contracts are
DVD's (MIT, github.com/theredguild/damn-vulnerable-defi).
