# Research Log — 2026-06-03 — PoCs: 11 new DeFiHackLabs-mined detector classes (v2.0.0)

## Done
- Built all **11** backlog rows from `intake/backlog.md` "Mined from DeFiHackLabs" as full
  Aegis units: deep-dive `docs/exploits/<id>.md` + `catalog/exploits.yaml` entry
  (`root_cause`/`applies_when`/`variant_queries`/`probes`/`invariant`) + minimal
  `Vulnerable<X>` + `Safe<X>` + Foundry test. Catalog **10 → 21 coded**; `forge test` →
  **44 passed / 0 failed** (21 suites). Flipped the 11 backlog rows `todo → promoted`.
- **ctoken-empty-market-exchange-rate** (SC07/SC02): `exchangeRate = cash/totalSupply` in an
  empty market; attacker mints 1 cToken, donates 5e18, victim's 4e18 deposit rounds to 0
  cTokens and is siphoned (attacker profit = victim's 4e18). Safe = seeded dead shares +
  `require(minted>0)`. The lending-market twin of `erc4626-inflation`.
- **approval-drain-arbitrary-call** (SC05/SC01): router does `target.call(data)` while holding
  approvals → attacker passes `target=token, data=transferFrom(victim,attacker)`; drains the
  full victim approval. Safe = adapter allow-list.
- **proxy-storage-collision** (SC01): proxy `admin` at sequential slot 0 collides with the
  impl's slot-0 var; `initialize()` through the proxy overwrites `admin`, then the attacker
  upgrades. Safe = EIP-1967 unstructured slots.
- **signature-replay-malleability** (SC01): no-nonce/no-domain sig replayed 5× to over-withdraw;
  `(v⊕1, r, n−s)` is a second valid sig for the same message. Safe = EIP-712 + per-account
  nonce + low-s (`s <= secp256k1n/2`) + zero-address guard.
- **unprotected-privileged-fn** (SC01): ungated `mint` (anyone prints supply) + re-callable
  `initialize` (anyone seizes ownership). Safe = `onlyOwner` + one-shot initializer.
- **insecure-randomness** (SC09): lottery draws from `block.timestamp/prevrandao`; attacker
  contract recomputes the draw and only enters winning blocks (zero-risk). Safe = entries
  locked, winner settled from an external VRF word (only the coordinator can settle).
- **weird-erc20-accounting** (SC02): vault credits the requested amount on a 10%-fee token →
  `sum(credited) > balance`, late LP shorted. Safe = credit the measured `balanceOf` delta.
- **incorrect-reward-accounting** (SC02): MasterChef harvest pays `pending` but never advances
  `rewardDebt` → re-harvest 5× = 5× entitlement. Safe = checkpoint `rewardDebt` on harvest.
- **unverified-flashloan-callback** (SC05/SC01): `onFlashLoan` with no `msg.sender==lender` /
  `initiator==address(this)` check is called directly to drain working capital. Safe = both
  checks.
- **bridge-deposit-no-code-token** (SC02, id was `qubit-bridge-deposit-logic`): a low-level
  `transferFrom` to a codeless address returns `(true, "")`, so the bridge credits a deposit
  that never moved (Qubit $80M). Safe = `token.code.length > 0` + allow-list.
- **first-deposit-amm-skim** (SC07): UniV2-fork with no `MINIMUM_LIQUIDITY` lock; first LP
  donates to inflate share price so a later LP's `min()` mints 0 LP and is skimmed. Safe =
  burn `MINIMUM_LIQUIDITY` on first mint + `require(liquidity>0)`.

## Notes
- Two PoC tests initially hit `vm.prank` consumption (a nested `pair.balanceOf(attacker)` /
  `ct.balanceOf(attacker)` ate the single-call prank, so `redeem`/`removeLiquidity` ran as the
  test contract and underflowed `balanceOf[msg.sender] -= x`). Fixed by capturing the balance
  before the prank. Worth a checklist note for our own PoCs.
- All 11 are native-EVM models of recurring classes (not single incidents); each catalog entry
  carries a `fork_poc` pointer to the DeFiHackLabs replay where one exists. No DHL PoC code was
  copied — patterns only, per the 2026-06-02 durability decision.

## Next
- Cut the **v2.0.0** tag + GitHub release (CHANGELOG `[2.0.0]` written; README Status bumped).
- Backlog still has the P1/P2 *seed candidates* (Euler, Curve-Vyper, KyberSwap, Wormhole,
  Nomad, Rari/Fei, Penpie, Platypus) as `todo` — next batch.
