# Research Log — 2026-06-04 — DVD v4 18/18 + 4 wargame-mined detector classes

## Done

### DVD v4 → 18/18 (finished the last two)
- **Wallet Mining (#14):** solved in the real DVD harness. `AuthorizerUpgradeable.needsInit`
  (slot 0) collides with `TransparentProxy.upgrader` (slot 0); after `setUpgrader`, slot 0 is the
  non-zero upgrader so `needsInit != 0` and `init()` is replayable → self-authorize for the deposit
  address. Brute-forced the Safe `saltNonce` (**= 13**) onto `USER_DEPOSIT_ADDRESS`, `drop()`-deployed
  it + collected the reward, swept the 20M DVT with the user's **off-chain** EIP-712 Safe signature —
  all inside an attacker constructor (the player's single tx). `forge test` green.
- **Curvy Puppet (#17):** solved on a **mainnet fork @ 20190356**. The lender prices the borrow asset
  (Curve stETH/ETH LP) as `oracle(ETH)·get_virtual_price()`, and `get_virtual_price()` is unguarded
  during `remove_liquidity` (LP burned + ETH paid before stETH). Empirically measured the inflation:
  ballooning the pool with **80k ETH + 220k stETH** (Aave flash loan) spikes vp to **~4.3×** in the
  ETH callback → all 3 positions underwater → liquidate all three in one reentrant sweep. Same-asset
  repay (wstETH unwrap/wrap + Lido `submit`); treasury's 200 WETH buffer covers Aave premiums + the
  Curve fee. Empirical scan recorded in commit msg (vp vs add-size table). `forge test` green.
- Report + READMEs flipped 16/18 → **18/18**. Solutions vendored to `dvd/solutions/test/`.

### 4 new catalog detectors mined from the wargames (cross-checked vs the 27 existing)
Added as full Aegis units (`docs/exploits/<id>.md` + `catalog/exploits.yaml` entry with
`root_cause`/`applies_when`/`variant_queries`/`probes`/`invariant` + `Vulnerable<X>`+`Safe<X>`+test +
checklist item + semgrep rule). Catalog **27 → 31 coded**; the 4 new PoC suites = **11 tests, all
green**; full `poc` suite **64 passed / 0 failed**.
- **meta-tx-msgsender-spoof** (SC01) — DVD Naive Receiver. ERC-2771 `_msgSender()` is only honest if
  the forwarder authenticates the appended `from`; a signature-less forwarder lets an attacker debit a
  victim and pay themselves. Safe = restricted forwarder set + EIP-712 sig + nonce.
- **calldata-abi-smuggling** (SC05/SC01) — DVD ABI Smuggling, Ethernaut Switch/HigherOrder. Guard reads
  the selector at a fixed `calldataload(0x44)` while forwarding a dynamic `bytes` whose offset the
  attacker controls → allowed selector passes, `sweepFunds` runs (drained 10 ETH in the PoC). Safe =
  validate `actionData[:4]`.
- **forced-ether-balance-assumption** (SC02) — Ethernaut Force/King. `require(address(this).balance ==
  totalDeposited)` bricked permanently by one `selfdestruct`-forced wei. Safe = internal accounting + `>=`.
- **dos-griefing-revert** (SC10/SC02) — Ethernaut King/Denial. Mandatory push-refund to the current
  leader → a contract with a reverting `receive` freezes the auction for everyone. Safe = pull-payment.

### Docs site
- `docs/the-catalog.md` 27 → **31** detectors (+4 rows). `docs/pocs.md` +4 PoC blocks.
  `docs/index.md` count updated. Both wargame reports' "gaps" sections updated: the promoted classes
  now link to their detectors (✅), remaining gaps kept as to-do.

## Takeaways
- The wargames are a genuine detector mine: Force/King/Denial/Switch + DVD Naive Receiver / ABI
  Smuggling produced 4 reusable detectors in one pass — the loop working as intended.
- Curvy Puppet adds **no new class** (it's the existing `read-only-reentrancy`), but the fork solve is
  a strong validation of that detector against a live Curve pool. The empirical vp-vs-size scan is the
  reusable artifact, not the plumbing.

## Next
- Remaining Ethernaut gap classes still un-encoded: information-exposure (`private` ≠ secret),
  integer/storage underflow (pre-0.8 / `unchecked`), `tx.origin` auth (have a semgrep rule, no full
  entry), untrusted-interface assumptions (Elevator/Shop). A generic precision-asymmetry detector
  (DVD Shards) is also open.
- Backlog still has 9 P1/P2 DeFiHackLabs seed rows in `intake/backlog.md` (`todo`): euler-donation,
  curve-vyper-reentrancy, kyberswap-tick, wormhole-sigverif, nomad-init, cream/rari/penpie reentrancy,
  platypus-logic.
