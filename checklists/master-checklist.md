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

- [ ] 👁 **SC02-GOV-1:** Is governance voting power computed from **snapshots at proposal
      creation** or from **real-time balances**? If real-time, flash-loan-acquired tokens
      can swing votes atomically. Check if `vote()` or `emergencyCommit()` reads
      Roots/Stalk/voting-power from current storage vs a snapshot block.
      *Beanstalk: $181M — flash-loaned $1B in LP → deposited for Roots → supermajority
      vote → emergency commit → drain, all in one tx.*
- [ ] 👁 **SC02-GOV-2:** Is there a **minimum delay** between proposal submission and
      execution that exceeds the time needed for tokenholders to detect and react (e.g.,
      7 days, not 1 day)? Can the delay be bypassed via `emergencyCommit` or fast-track?
      *Beanstalk: 1-day emergency delay was insufficient; attacker pre-submitted the
      malicious proposal 24 hours before, then executed in one atomic tx.*
- [ ] 👁 **SC02-GOV-3:** After a governance proposal executes, is there a **timelock
      before asset-affecting changes take effect**, giving users time to exit? Or can
      `cutBip()` / `execute()` drain assets atomically?
      *Beanstalk: `cutBip()` executed immediately via Diamond proxy, no grace period.*
- [ ] 👁 **SC02-SWAP-1:** For multi-hop swap routes (margin opening, collateral conversion,
      flash loan repayment), is `min_amount_out` validated only on the **terminal output
      token**, or is it accumulated across intermediate hops? Summing intermediate values
      inflates the validated minimum, allowing positions to pass safety checks with
      fabricated routes. Also: does post-swap validation compare actual output against the
      validated minimum, or does it credit whatever arrives?
      *Rhea Finance: $18.4M — `get_token_out()` summed all `min_amount_out` values
      including intermediate hops, inflating the validated minimum 4.1M×. Post-swap
      `on_open_trade_return()` credited whatever arrived without re-checking.*

- [ ] 🤖 **SC02-AC:** Is every function that modifies access-control state (whitelists,
      role mappings, authorized-signer lists) restricted to admin/trusted callers?
      Check for `public` visibility on setter functions for `mapping(address => bool)`
      patterns. *TrustedVolumes: $6.7M — `setAuthorizedSigner` was public with no modifier,
      attacker added self to whitelist, forged trade orders.*
- [ ] **SC02-BRIDGE:** For bridge contracts: Is cross-chain message verification based on
      a well-audited Merkle library (e.g., OpenZeppelin MerpleProof)? Are roots validated
      against signed validator attestations, not just computed values? Is there a fallback
      mechanism (guardian watchtower) for suspicious withdrawals? *Verus Bridge: $11.6M —
      forged Merkle proofs accepted as valid cross-chain withdrawal authorization.*
- [ ] **SC02-LEGACY:** Are deprecated/legacy contracts still accessible on-chain? Even if
      the frontend disables them, can they be called directly? *Transit Finance: $1.88M —
      deprecated TRON contract from 2022 with known vulnerabilities still callable.*
- [ ] 👁 **SC02-SOLVER-1:** Does the contract use an **iterative solver** (Newton-Raphson,
      binary search, fixed-point iteration) to compute a critical invariant (supply, price,
      rate)? If so: (a) are domain preconditions (e.g., `A·Σ ≥ D·Π`) explicitly checked
      before and during iteration? (b) does the solver detect and **revert on divergence**
      (product term → 0, oscillation, non-convergence)? (c) is arithmetic in invariant-critical
      paths **checked** (not `unsafe_sub` / `unchecked`)? *Yearn yETH: $9M — solver divergence
      drove Π to 0, then `unsafe_sub` underflow minted 2.35 × 10⁵⁶ LP tokens.*
- [ ] 👁 **SC02-REINIT-1:** Is there a **bootstrap/initialization path** that can be re-entered
      after the contract has been used in production? Can `prev_supply == 0` (or equivalent
      "empty pool" state) be reached while ERC-20 balances still exist (e.g., via POL)?
      If so, the initialization path becomes an exploit primitive — it was designed for
      first-deposit math, not adversarial inputs on a mature pool. *Yearn yETH: $9M —
      after draining the pool, the attacker re-entered the bootstrap path with dust deposits
      that triggered a uint256 underflow in the initialization math.*
- [ ] 👁 **SC02-POL-1:** Does the protocol maintain **Protocol-Owned Liquidity (POL)** that
      absorbs supply reconciliation (burns/mints to match internal invariant `D` vs
      `totalSupply`)? Can an attacker manipulate `D` to trigger POL burns, offloading
      the cost of over-minted LP onto the protocol rather than the attacker? *Yearn yETH:
      $9M — `update_rates` burned yETH from the staking contract to reconcile the
      attacker-inflated `D`, draining POL instead of the attacker's balance.*


## SC03 — Price Oracle Manipulation 👁🤖
- [ ] Is any price derived from a **spot** AMM reserve / `getReserves` / `balanceOf`
      of a pool? (manipulable in-tx via flash loan). 🤖 grep for spot-price reads.
- [ ] If TWAP: is the window long enough to be flash-loan-resistant? *Inverse Finance:
      manipulated SushiSwap TWAP → over-borrow, $15.6M.*
- [ ] Single oracle source vs. multiple? Staleness check on Chainlink `updatedAt`?
      `answeredInRound`? Min/max bounds?
- [ ] Does the protocol price LP tokens / LSTs / rebasing tokens correctly (not via
      naive `balanceOf`)?
- [ ] Is the oracle price source **endogenous** to the protocol (derived from the
      protocol's own markets)? If so, an attacker can create a self-referential
      pricing loop. *Mango Markets: $4M in buys on Mango's own markets moved the
      oracle price 23x, unlocking $114M in borrowing.*
- [ ] Are there **circuit breakers / deviation bounds** that halt borrowing or
      liquidations when the oracle price moves more than X% within Y minutes?
      *Mango Markets: 2,300% spike in 20 minutes with no safety trigger.*
- [ ] Is collateral **isolated by asset type**, or can a single manipulated asset
      unlock borrowing against all other assets via cross-margin? *Mango Markets:
      MNGO-PERP gains could borrow USDC, SOL, BTC, ETH with no per-asset caps.*

## SC07 — Arithmetic / Precision 👁🤖 (the quiet killer in mature AMMs)
- [ ] Rounding **direction** on every division — does it ever favor the caller?
      *Balancer V2 ComposableStablePool: rounding edge case distorted accounting, ~$128M.*
- [ ] 🤖 **SC07-R2:** Do upscaling and downscaling operations use **consistent directional
      rounding**? If downscaling uses `divUp`/`divDown`, does upscaling use the matching
      `mulUp`/`mulDown`? A mismatch (e.g., always-round-down `_upscale` paired with
      directional `_downscale`) silently deflates invariant calculations.
      *Balancer V2: `_upscale()` always used `mulDown`, but `_swapGivenOut()` needed
      `mulUp` for output amounts — 65 micro-swaps compounded the error into $128M.*
- [ ] 🤖 **SC07-R3:** Have you tested invariant preservation with **small balance values**
      (1-20 wei range)? Rounding errors are proportionally largest for tiny amounts
      (e.g., 8 wei × scaling factor → 12.5% precision loss). Fuzz with `balance < 100`.
- [ ] 👁 **SC07-R4:** For `batchSwap` / multi-hop functions: can an attacker **compound**
      tiny per-operation rounding errors across many hops in a single atomic tx?
      Individual swaps may be safe, but 65+ sequential swaps can amplify a 1-wei error
      into millions. Test with maximum-length swap batches.
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
- [ ] 👁 **SC07-UNSAFE-1:** Are `unsafe_math` / `unchecked` blocks used in **invariant-critical
      calculations** where the operands can be influenced by user input (deposits, withdrawals,
      swaps)? If `A - B` can underflow due to adversarial inputs, the result wraps to
      `uint256` max instead of reverting — turning a domain violation into a catastrophic
      mint or drain. *Yearn yETH: $9M — `unsafe_sub(A*Σ, D*Π)` in `_calc_supply` wrapped
      to ~2^256 when `D*Π > A*Σ`, minting 2.35 × 10⁵⁶ LP tokens.*

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

## X04 — Cryptographic / TSS 👁 (threshold signatures, key management)
- [ ] 👁 **X04-TSS:** For protocols using threshold signatures (GG20, FROST, DKLS): Is the
      TSS library current with upstream? Are all cryptographic proofs (MOD, FAC, MtA)
      verified during key generation? Check for CVE-2023-33241 / TSSHOCK in any GG20
      implementation. *THORChain: $10.8M — tss-lib fork was 3 years behind upstream,
      skipped MOD/FAC proof checks. Malicious node registered malformed Paillier modulus,
      extracted key share residues from signing rounds, reconstructed vault private key.*
- [ ] 👁 **X04-TSS-SYBIL:** For permissionless node/operator bonding in TSS-based systems:
      Is there Sybil resistance beyond economic stake? Can an attacker bond the minimum,
      churn into the active set, and become a co-signer with no reputation/history check?
      *THORChain: attacker bonded 635K RUNE, churned in within days, no history check.*
- [ ] 👁 **X04-TSS-AUDIT:** Has the TSS library been audited **after** the latest known
      CVE disclosure for that cryptographic scheme? Pre-CVE audits are stale — the
      vulnerability class they missed is the one that gets exploited. *THORChain:
      Trail of Bits audit predated CVE-2023-33241 disclosure by months.*

## X05 — Contract Lifecycle / Legacy Risk 👁 (deprecated ≠ disabled)

- [ ] 👁 **X05-LEGACY-APPROVAL:** When deprecating a contract, are user approvals explicitly
      revoked or migrated? A "deprecated" contract that still holds active ERC20/TRC20 approvals
      is a standing drain vector — anyone who can call the contract can exploit the approvals.
      *Transit Finance: $1.88M (2026) — same contract exploited for $21M in 2022, "deprecated"
      by removing the frontend, but approvals persisted for 3.5 years.*
- [ ] 👁 **X05-LEGACY-PAUSE:** Does every deployable contract have a `pause()` or `emergencyStop()`
      mechanism that can be triggered by the admin? If a contract is deprecated, is it actually
      paused (not just removed from the frontend)? Direct on-chain calls bypass frontend removal.
      *Transit Finance: legacy contract had no pause mechanism; "deprecation" was purely off-chain.*
- [ ] 👁 **X05-LEGACY-SCAN:** Is there a periodic scan for deprecated contracts that still hold
      active approvals? Approval management tools (Revoke.cash, etc.) can flag stale approvals,
      but only if users know to check. Protocols should proactively notify users to revoke
      approvals to deprecated contracts.

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
- [ ] Does any pay/settle function forward arbitrary trailing calldata to a callback
  (via `calldatacopy`) and verify only its own balance delta? A malicious callback
  can use pre-existing third-party approvals to fund the repayment — the protocol
  becomes a drain rail. `SC02-CB-1` *Ekubo: $1.4M via callback calldata injection
  (2026-05-05). SwapNet: $17M calldata injection (2026-01-25).*
- [ ] In flash-accounting / callback-based routers, does the repayment verification
  check the *source* of funds (e.g., `msg.sender` balance change) or only the
  *contract's* balance? If only the latter, any approved contract can be
  weaponized as a drain rail. `SC02-CB-2`
- [ ] Does the callback interface allow the caller to inject arbitrary recipient/
  amount parameters via forwarded calldata that get passed to `transferFrom`?
  If so, standing approvals to the callback contract create a drain vector. `SC02-CB-3`

### Lending / Borrowing
- [ ] Does liquidation work during rapid downturns / when paused / when resumed? `SOL-Defi-Lending-1`,`-4`,`-5`
- [ ] Self-liquidation for undue profit? `SOL-Defi-Lending-3`
- [ ] Front-run a tiny collateral top-up to dodge liquidation? `SOL-Defi-Lending-6`
- [ ] Is accrued **interest** included in the LTV/health-factor calc? `SOL-Defi-Lending-8`
- [ ] Borrow + lend (or lend+borrow) the **same token in one tx**? `SOL-Defi-Lending-10`
- [ ] Can a position become **unrepayable** (locked bad debt)? `SOL-Defi-Lending-12`
- [ ] When pricing collateral via external calls (CPI, oracle adapters, cross-program
  queries), is the **external source identity validated** against a known-good value?
  (Not just the data — the *source* itself.) *Loopscale: CPI to user-supplied "RateX"
  program returned inflated PT prices → $5.8M undercollateralized loans.*
- [ ] If the protocol supports **multiple collateral types**, does each type enforce the
  **same validation checks** (program ID, account constraints, price bounds)? Inconsistency
  between adapters is a signal. *Loopscale: RateX adapter (added post-launch) lacked
  program-ID checks that other PT adapters had.*

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
- [ ] **X01-DVN-CONFIG:** For DVN-based bridges (LayerZero, etc.): Does the DVN configuration
      require ≥2 independent verifiers from different infrastructure providers? Is `requiredDVNs.length >= 2`?
      Are deployment scripts enforcing minimum DVN count (not just docs)? Is `optionalDVNs` populated as
      fallback? Do DVN admin addresses NOT overlap across registrations? *Kelp DAO: $292M — 1-of-1 DVN
      config meant a single compromised verifier authorized a forged cross-chain message. 47% of LayerZero
      OApps had the same vulnerable default.*
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

- [ ] 👁 **SC02-MMR-BOUNDS:** For MMR/Merkle verifiers: After the peak/proof decomposition
      loop, are unconsumed leaves explicitly rejected? Are duplicate leaf indices forbidden?
      Is the proof validated to be non-empty and canonical (no trailing data)?
      *Hyperbridge: $237K extracted, 1B tokens minted — out-of-bounds leaf silently
      skipped by peak loop. Same bug class found in 3 independent Merkle libraries.*
- [ ] 👁 **SC02-PROOF-BIND:** For cross-chain message handlers: Is each message
      cryptographically bound to its proof, or can a proof for one message validate a
      different message? Can an attacker recycle data from a previously legitimate
      transaction to construct a forged proof? *Hyperbridge: attacker decoupled proof
      from message — proof for a real transaction validated a forged ChangeAssetAdmin.*
- [ ] 👁 **SC02-CHALLENGE-PERIOD:** For bridge contracts with a challenge/dispute period:
      Is the challenge period non-zero and sufficient for validators/fishermen to detect
      and dispute forged commitments? Can it be set to zero by governance? A zero
      challenge period means forged state commitments execute instantly with no recourse.
      *Hyperbridge: challengePeriod was 0, disabling the built-in defense against forged
      proofs. The attacker's ChangeAssetAdmin executed with no dispute window.*
