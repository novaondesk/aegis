# Master Review Checklist — the Suite (v0)

Walk this against any contract during the **REVIEW** phase. Each item is phrased as a
question + the code smell + the real exploit that justifies it. Items are grouped by
OWASP SC class. This is a living document — every new case study should add or sharpen
items here.

Legend: 🤖 = an automated tool/rule can flag candidates · 👁 = needs human judgment.

---

## SC02 — Business Logic 👁 (highest value, lowest automation)
- [ ] Does every state-changing path preserve the protocol's core accounting identity?
      (e.g. `sum(balances) == totalSupply`, `assets == shares * pps`). *Yearn yETH:
      share-calc flaw → near-infinite mint.*
- [ ] Can the **first depositor** manipulate share price (empty-vault / share inflation
      attack)? Is there a dead-shares / min-liquidity mint?
- [ ] Are deposit/withdraw/borrow/repay symmetric? Any asymmetry an attacker can loop?
      *TMXTribe: looped mint-and-stake.*
- [ ] Do fee/reward calculations round in the **protocol's** favor, never the user's?
- [ ] Can a function be called in an unexpected **order** or **state** (uninitialized,
      paused, post-migration) to extract value?
- [ ] Governance: can a proposal be created + executed within one tx / one block?
      *Beanstalk: flash-loan → supermajority → drain.*

## SC03 — Price Oracle Manipulation 👁🤖
- [ ] Is any price derived from a **spot** AMM reserve / `getReserves` / `balanceOf`
      of a pool? (manipulable in-tx via flash loan). 🤖 grep for spot-price reads.
- [ ] If TWAP: is the window long enough to be flash-loan-resistant? *Inverse Finance:
      manipulated SushiSwap TWAP → over-borrow, $15.6M.*
- [ ] Single oracle source vs. multiple? Staleness check on Chainlink `updatedAt`?
      `answeredInRound`? Min/max bounds?
- [ ] Does the protocol price LP tokens / LSTs / rebasing tokens correctly (not via
      naive `balanceOf`)?

## SC07 — Arithmetic / Precision 👁🤖 (the quiet killer in mature AMMs)
- [ ] Rounding **direction** on every division — does it ever favor the caller?
      *Balancer V2 ComposableStablePool: rounding edge case distorted accounting, ~$95M+.*
- [ ] Order of operations: multiply-before-divide to preserve precision?
- [ ] Fixed-point math: mismatched decimals (6 vs 18), scaling factors, WAD/RAY mixups?
- [ ] Can a tiny/zero-value input (1 wei, 0 shares) trigger a divide-by-zero or a
      rounding exploit?
- [ ] Liquidity / invariant math (`x*y=k`, stableswap `D`): any term that can overflow
      intermediate before downcast? *Cetus: liquidity math overflow, ~$223M.*

## SC01 — Access Control 🤖👁
- [ ] Every privileged function gated (`onlyOwner`/role) — including initializers,
      upgrade hooks, sweep/rescue functions? 🤖 slither flags missing modifiers.
- [ ] Is `initialize()` protected against being called twice / front-run on deploy?
      *Rubixy: constructor naming error left ownership transfer public.*
- [ ] `tx.origin` used for auth anywhere? (phishing vector)
- [ ] Can role admin be transferred to address(0) or self-renounced into a brick?

## SC08 — Reentrancy 🤖👁
- [ ] Checks-Effects-Interactions on every external-call function? State updated
      **before** the call? *Rari Capital: borrow() lacked CEI, $80M.*
- [ ] **Read-only reentrancy**: does a view function return stale state mid-callback
      that another protocol trusts? (modern, tool-blind)
- [ ] Cross-function & cross-contract reentrancy (shared state, ERC777/ERC721 hooks,
      ERC-1155 callbacks, native `call` to attacker-controlled address)?
- [ ] `nonReentrant` actually applied to *all* entrant paths, not just one?

## SC04 — Flash-Loan Facilitated 👁
- [ ] For each "magnify a bug" item above: would a flash loan make it profitable in a
      single atomic tx? Model it.
- [ ] Any logic that assumes balances/prices can't move within a tx?
- [ ] Governance/voting power snapshotted at the **wrong** time (current balance vs.
      historical)?

## SC06 — Unchecked External Calls 🤖
- [ ] Return value of low-level `.call`/`.send`/`.transfer` checked? 🤖
- [ ] ERC20 `transfer`/`transferFrom` return value checked (non-reverting tokens)?
      SafeERC20 used?
- [ ] Fee-on-transfer / rebasing / non-standard tokens handled (received != sent)?
- [ ] External call to a user-supplied address/contract? (arbitrary-call sink)
      *Dexible: arbitrary router → malicious code, $2M.*

## SC05 — Input Validation 🤖👁
- [ ] Address params checked for `address(0)` / self / contract-vs-EOA where it matters?
- [ ] Array length / bounds; deadline & slippage params present and enforced?
- [ ] **Cross-chain message** payloads validated for source chain + sender + nonce?
      *Kelp rsETH: cross-chain verification config failure, $292M (config layer).*

## SC10 — Proxy & Upgradeability 🤖
- [ ] Storage layout collision between impl versions? Gap variables present?
- [ ] `_disableInitializers()` in impl constructor? Uninitialized impl seizable?
- [ ] Upgrade authority: timelock? multisig? Can a single key rug via upgrade?
- [ ] `delegatecall` to untrusted/user-controlled target?

## SC09 — Overflow/Underflow 🤖
- [ ] Solidity <0.8 without SafeMath anywhere? `unchecked{}` blocks audited by hand?
      *Poolz: overflow in GetArraySum(), $390K.*

## DoS / griefing 👁
- [ ] Unbounded loops over user-growable arrays? Push-payment that one revert can brick?
      (use pull-payments)
- [ ] Can an attacker force a critical function to always revert (e.g. by donating dust,
      or being the recipient of a forced transfer)?

## Weak randomness 🤖
- [ ] `block.timestamp`/`blockhash`/`prevrandao` used for anything valuable? (use VRF)

---

## How to run this
1. Run automated suite first (`tools/`), record which 🤖 items got candidates.
2. Walk every 👁 item by hand — these are where bounties live.
3. For any "yes/maybe", write a one-line hypothesis → prove with a Foundry PoC.
4. New exploit studied? Backport a sharper item here + a semgrep rule + an invariant.
