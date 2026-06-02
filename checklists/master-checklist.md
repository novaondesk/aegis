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
- [ ] Does deposit/withdraw/borrow/repay symmetric? Any asymmetry an attacker can loop?
      *TMXTribe: looped mint-and-stake.*
- [ ] **Solana: trusted-root validation** — when validating account chains (bank → collateral → swap → mint), is the root anchored to a program-controlled source? Can an attacker create a parallel universe of fake accounts that passes all `assert_keys_eq!` checks? *Cashio: $52.8M — fake bank → fake Saber swap → fake LP → real CASH mint.*
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
- [ ] Bit-shift operations: are "checked" shift wrappers verified with boundary inputs
      (`n == threshold`, `n == threshold+1`)? Languages where `+`/`*` abort on overflow
      but `<<` silently truncates (Move, Rust `wrapping_shl`) are especially dangerous.
      *Cetus: wrong constant in `checked_shlw` mask — `0xff...ff << 192` instead of
      `1 << 192` — let a ~2^192 intermediate pass undetected.* 🤖

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
      that another protocol trusts? (modern, tool-blind) — worked PoC:
      `docs/exploits/read-only-reentrancy.md` + `poc/test/ReadOnlyReentrancy.t.sol`.
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

---

## Protocol-archetype playbooks 👁

Hunters approach by *what the protocol is*, not just by bug class. These are the
highest-signal questions per archetype, promoted from the Solodit mining (see
`solodit-aggregated-checklist.md` for the full 370-item backstop). Each maps to real
losses.

### Vault / ERC-4626
- [ ] First-depositor / share-inflation: can attacker mint 1 share then donate to
      inflate `pps` and steal the next depositor's funds? Dead-shares mitigation? `SOL-Defi-General-4`
- [ ] Donation attack: does accounting use `balanceOf(this)` instead of internal
      tracking? (direct transfer skews share price) `SOL-AM-DA-1`
- [ ] Deposit + withdraw in the **same tx/block** allowed? (flash-loan share games) `SOL-Defi-General-8`, `SOL-Defi-FlashLoan-2`
- [ ] What happens with **1 wei** left in the pool? Rounding/divide-by-zero. `SOL-Defi-General-7`

### AMM / Swap
- [ ] Slippage: hardcoded? calculated on-chain (manipulable)? enforced at the *last*
      step before transfer? `SOL-Defi-AS-1`,`-13`,`-14`
- [ ] Deadline protection present? `SOL-Defi-AS-2`
- [ ] Callback functions verify the **caller** address? (fake-pool callback drain) `SOL-Defi-AS-12`
- [ ] Fee-on-transfer / rebasing / non-18-decimal tokens handled? `SOL-Defi-AS-9`,`-10`,`-8`
- [ ] Rounding in the constant-product / invariant formula. `SOL-Defi-AS-5`

### Lending / Borrowing
- [ ] Does liquidation work during rapid downturns / when paused / when resumed? `SOL-Defi-Lending-1`,`-4`,`-5`
- [ ] Self-liquidation for undue profit? `SOL-Defi-Lending-3`
- [ ] Front-run a tiny collateral top-up to dodge liquidation? `SOL-Defi-Lending-6`
- [ ] Is accrued **interest** included in the LTV/health-factor calc? `SOL-Defi-Lending-8`
- [ ] Borrow + lend (or lend+borrow) the **same token in one tx**? `SOL-Defi-Lending-10`
- [ ] Can a position become **unrepayable** (locked bad debt)? `SOL-Defi-Lending-12`

### Liquid Staking Derivatives (LSD)
- [ ] Exchange-rate repricing sandwichable to drain? `SOL-Defi-LSD-2`
- [ ] Reentrancy on ETH send / `_safeMint` of withdrawal NFTs? `SOL-Defi-LSD-3`
- [ ] Arbitrary exchange rate settable on queued withdrawals? `SOL-Defi-LSD-4`
- [ ] Precision loss in deposit/withdraw/reward math? `SOL-Defi-LSD-9`

### Staking / Rewards
- [ ] Rewards up-to-date in **all** paths (claim before/after stake changes)? `SOL-Defi-Staking-3`
- [ ] Can one user grief another's lock duration by staking on their behalf? `SOL-Defi-Staking-1`

### Signatures (permit / meta-tx / cross-chain msgs)
- [ ] Replay-guarded (nonce + chainId + contract addr in the digest)? `SOL-Signature-1`
- [ ] Malleability handled (use ECDSA lib, reject high-s)? `SOL-Signature-2`
- [ ] ecrecover return checked against `address(0)` and expected signer? `SOL-Signature-3`,`-4`
- [ ] Deadline enforced? `SOL-Signature-5`

### Multi-chain / Cross-chain (Kelp-class territory)
- [ ] Cross-chain message verifies **source chain + sender + nonce**; DVN/verifier set
      not a single point of failure? `SOL-McCc-8`, X01
- [ ] `block.number`/`block.timestamp` assumed consistent across chains? `SOL-McCc-1`
- [ ] ERC20 decimals consistent across chains? `SOL-McCc-6`
- [ ] `PUSH0`/opcode compatibility on every target chain (zkSync etc.)? `SOL-McCc-3`,`-12`

> ⚠️ **Scope note:** the mined Solodit checklist and these playbooks are **Solidity/EVM-centric**.
> Project scope also includes **Solana (Rust/Anchor)** and **Sui/Move** — those need
> separate, ecosystem-specific checklists (e.g. Anchor account-validation / signer
> checks, Move resource & ability model). Tracked in the research-log backlog.

---

## How to run this
1. Run automated suite first (`tools/`), record which 🤖 items got candidates.
2. Walk every 👁 item by hand — these are where bounties live.
3. For any "yes/maybe", write a one-line hypothesis → prove with a Foundry PoC.
4. New exploit studied? Backport a sharper item here + a semgrep rule + an invariant.
