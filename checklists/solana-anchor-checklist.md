# Solana / Anchor Security Checklist

Exploit-derived, bounty-relevant checks for Solana programs built with Anchor.
Each item is a yes/no question + the code smell + a real exploit that maps to it.

> **How to use:** Walk through this list for every Solana program under review.
> A "no" answer on any item is a finding candidate — escalate to PoC.

---

## Oracle & Price Feed

### SOL-ORACLE-1 — Spot price used as sole oracle for collateral/loan valuation?
- **Code smell:** Direct call to `get_pool_spot_price()` or AMM `getAmountOut`-equivalent
  in a collateral valuation function without TWAP, multi-source aggregation, or staleness check.
- **Why it matters:** A flash-loan-sized trade can skew a thin pool's spot price within a
  single transaction, enabling undercollateralized loans or overpriced liquidations.
- **Real exploit:** Loopscale (April 2025, $5.8M) — RateX PT pricing used single spot price,
  flash-loan manipulation → undercollateralized loan → vault drain.
- **Fix:** Use Pyth/Switchboard TWAP feeds, multi-oracle median, or at minimum a
  time-weighted check with a configurable staleness window.
- **Severity:** CRITICAL — direct theft of user funds.
- **Bounty context:** $50K–$250K on typical Immunefi critical tier for lending protocols.

### SOL-ORACLE-2 — Oracle account address validated against a known/expected program?
- **Code smell:** Passing a `price_feed` account via `AccountInfo` without checking
  `owner == PYTH_PROGRAM_ID` or `owner == SWITCHBOARD_PROGRAM_ID`.
- **Why it matters:** Attacker can pass a fake oracle account they control, setting any price.
- **Real exploit:** Mango Markets (October 2022, $114M) — spot oracle manipulation
  (different mechanism, but same class: trusting an unvalidated price source).
- **Fix:** Validate oracle account owner in the Anchor account constraints:
  `constraint = price_feed.owner == &PYTH_PROGRAM_ID @ ErrorCode::InvalidOracle`
- **Severity:** CRITICAL

### SOL-ORACLE-3 — No staleness check on oracle price?
- **Code smell:** Reading `price.price` without checking `price.publish_time` against
  `Clock::get()?.unix_timestamp` with a max age threshold.
- **Why it matters:** An oracle that hasn't updated recently may reflect stale prices,
  especially dangerous during high volatility or oracle downtime.
- **Fix:** `require!(now - price.publish_time < MAX_STALENESS_SECS, ErrorCode::StaleOracle)`
- **Severity:** HIGH

### SOL-ORACLE-4 — Oracle accepts collateral without minimum liquidity validation? 🤖
- **Code smell:** Oracle evaluates collateral price from a DEX pool without checking underlying pool liquidity depth, number of unique traders, or time-weighted volume
- **Why it matters:** A token with trivial seed liquidity ($500) can be wash-traded to any target price. Price without liquidity is a fiction — it represents what someone *could* get if there were a counterparty, not what the market actually supports. An oracle that validates price but not depth allows an attacker to manufacture collateral from nothing.
- **Real exploit:** Drift Protocol (April 2026, $285M) — CarbonVote Token (CVT) deployed with ~$500 in seed liquidity on Raydium, wash-traded to ~$1, accepted as collateral by Switchboard oracle. Attacker deposited hundreds of millions in worthless CVT and withdrew real assets.
- **Fix:** Enforce minimum liquidity threshold (e.g., $1M+ pool depth) and minimum number of unique traders before listing any token as collateral. Validate liquidity on-chain, not just price.
- **Severity:** CRITICAL — direct theft of user funds via manufactured collateral.
- **Bounty context:** $100K–$500K on typical Immunefi critical tier for perps/lending protocols.

---

## Governance & Timelock 🤖👁

### SOL-GOVERNANCE-1 — Security Council / admin has zero timelock on privileged actions?
- **Code smell:** `timelock: 0` on Security Council configuration, or no timelock on governance actions that can list collateral, change withdrawal limits, or modify protocol parameters
- **Why it matters:** Timelocks exist to give the community and security teams time to detect and block malicious governance transactions. Zero timelock = zero detection window. When combined with compromised multisig signers, pre-signed malicious transactions execute instantly with no opportunity to intervene.
- **Real exploit:** Drift Protocol (April 2026, $285M) — Security Council migrated to 2-of-5 with zero timelock on March 27, 5 days before the exploit. The migration itself was approved through the already-compromised multisig.
- **Fix:** Minimum 48-hour timelock on all privileged governance actions. Timelock reduction should itself be timelocked at the original duration.
- **Severity:** CRITICAL
- **Bounty context:** Governance architecture flaws increasingly covered under Immunefi's "logical vulnerabilities" tier.

### SOL-GOVERNANCE-2 — Multisig threshold too low relative to TVL?
- **Code smell:** 2-of-N multisig where N < 7, especially for protocols with TVL > $100M
- **Why it matters:** A 2-of-5 multisig means compromising 2 individuals gives full control of $550M+ in user funds. Social engineering of 2 signers is a realistic attack for state-sponsored actors (DPRK/Lazarus Group).
- **Real exploit:** Drift Protocol (April 2026, $285M) — 2-of-5 multisig, social engineering of 2 signers gave full control. Attacker pre-signed malicious transactions via Solana durable nonces.
- **Fix:** Higher thresholds (4-of-7+) with geographically distributed signers, hardware key requirements, and transaction simulation before signing. Consider separating signing authority by function (e.g., collateral listing vs. withdrawal limits).
- **Severity:** HIGH

### Account Confusion / Type Cosplay
- [ ] Is there a discriminator check to prevent one account type being misinterpreted as another?
  - **Code smell:** Raw `AccountInfo` deserialization without type verification
  - **Exploit:** Cashio ($52M) — fake collateral accounts passed as valid
  - **Mitigation:** Always use Anchor's `Account<'info, T>` which includes discriminator checks

### Missing `has_one` / Account Relationship
- [ ] Are all authority/vault/mint relationships explicitly verified?
  - **Code smell:** Account passed without verifying it matches the expected authority
  - **Exploit:** Unauthorized operations on wrong accounts
  - **Mitigation:** Use `#[account(has_one = authority)]` constraints

### Trusted Root / Anchor-of-Trust Validation 👁
- [ ] When validating a chain of accounts (A → B → C → D), is the **root** of the chain anchored to a program-controlled or authority-gated source?
  - **Code smell:** `assert_keys_eq!` chain where any intermediate account is user-creatable without authorization
  - **Exploit:** Cashio ($52.8M) — attacker created a parallel universe of fake bank → fake Saber swap → fake Arrow → fake LP tokens. Every `assert_keys_eq!` passed because none anchored to a trusted root. The Arrow account's `mint` field was never validated against a known-good Saber LP mint.
  - **Mitigation:** Either (a) whitelist valid collateral mints in a program-controlled account, or (b) verify the deepest account in the chain is owned by a known program (e.g., `saber_swap.owner == SABER_PROGRAM_ID`), or (c) gate bank/collateral creation behind an authority check so attackers can't construct parallel chains.
  - **Detection heuristic:** For each `assert_keys_eq!` chain, ask: "Can an attacker create a fake version of the first account that satisfies all downstream checks?" If yes, the chain lacks a trusted root.

### Permissionless Initialization Risk 👁
- [ ] If any account in a validation chain can be created by any user (permissionless `init`), does the downstream instruction verify the account was created by an authorized authority?
  - **Code smell:** `crate_mint` / bank / pool creation without authority gate, followed by validation chains that trust user-created account fields
  - **Exploit:** Cashio — bank creation was permissionless. Attacker created a bank with worthless tokens, then used it to mint real CASH because no check verified the bank was authorized to issue CASH.
  - **Mitigation:** Gate account creation behind `has_one = authority` or require a program-controlled whitelist for accounts that participate in value-bearing operations.

### Arbitrary CPI
- [ ] Is the target program ID for CPI calls verified against an expected value?
  - **Code smell:** CPI to user-supplied program ID without validation
  - **Exploit:** Arbitrary code execution via malicious program
  - **Mitigation:** Hardcode expected program IDs or use Anchor's CPI modules

### PDA Bump Canonicalization
- [ ] Is `find_program_address` used instead of `create_program_address` with user-supplied bump?
  - **Code smell:** User-provided bump seed in PDA derivation
  - **Exploit:** PDA collision attacks, unauthorized signer access
  - **Mitigation:** Always use `find_program_address` which returns canonical bump

### Duplicate Mutable Accounts
- [ ] Are mutable accounts checked for uniqueness (same account not passed twice)?
  - **Code smell:** Two `#[account(mut)]` parameters of same type without key comparison
  - **Exploit:** Double-mutation attacks, balance manipulation
  - **Mitigation:** Add `require!(account1.key() != account2.key(), ErrorCode::DuplicateAccount)`

---

## Account Validation

### SOL-ACCOUNT-1 — Missing owner check on deserialized account?
- **Code smell:** Using `AccountInfo` directly instead of `Account<T>` with Anchor's
  discriminator check, or using `unchecked_account` for privileged operations.
- **Why it matters:** Attacker passes a fake account that mimics the expected layout,
  bypassing authority checks or injecting malicious data.
- **Real exploit:** Cashio (March 2022, $50M) — fake collateral accounts with no
  ownership validation → infinite mint of CASH stablecoin.
- **Fix:** Use `Account<'info, T>` (Anchor checks discriminator + owner) or explicitly
  validate `account.owner == program_id`.
- **Severity:** CRITICAL

### SOL-ACCOUNT-2 — Missing `has_one` or account-relationship constraint?
- **Code smell:** Privileged instruction takes `authority`, `vault`, or `mint` accounts
  without `has_one = authority` or `constraint = vault.key() == state.vault`.
- **Why it matters:** Attacker passes their own authority or a different vault to
  redirect funds or bypass access control.
- **Fix:** Anchor `has_one` constraints or explicit `constraint` checks on all
  linked accounts.
- **Severity:** HIGH

### SOL-ACCOUNT-3 — Duplicate mutable accounts?
- **Code smell:** An instruction takes two `Account<'info, T>` with `mut` but doesn't
  verify they're different (`constraint = account_a.key() != account_b.key()`).
- **Why it matters:** Passing the same account twice can bypass balance checks
  (e.g., transferring to yourself while updating both "sender" and "receiver").
- **Fix:** Add explicit key-inequality constraints.
- **Severity:** HIGH

---

## Signer & Authority

### SOL-SIGNER-1 — Privileged operation without signer check?
- **Code smell:** Admin/authority instruction doesn't require `Signer` or check
  `ctx.accounts.authority.is_signer`.
- **Why it matters:** Anyone can call the instruction without proving they control
  the authority wallet.
- **Fix:** Anchor `Signer<'info>` type or `require!(authority.is_signer)`.
- **Severity:** CRITICAL

### SOL-SIGNER-2 — PDA authority not validated against expected seeds/bump?
- **Code smell:** Accepting a user-provided `bump` seed or using
  `create_program_address` with user-supplied seeds instead of `find_program_address`.
- **Why it matters:** User-supplied bumps can create valid but unexpected PDAs,
  potentially crossing authority boundaries.
- **Fix:** Always use `find_program_address` with known seeds, store canonical bump
  in account data, and validate against it.
- **Severity:** HIGH

---

## CPI & Cross-Program Invocation

### SOL-CPI-1 — Arbitrary CPI to unchecked program ID?
- **Code smell:** `invoke()` or `invoke_signed()` with a `program_id` taken from
  an account parameter rather than hardcoded or validated.
- **Why it matters:** Attacker passes a malicious program that mimics the expected
  interface but drains funds or modifies state unexpectedly.
- **Fix:** Validate `program_id.key() == EXPECTED_PROGRAM_ID` before CPI, or use
  Anchor's `Program<'info, T>` type which checks the ID.
- **Severity:** CRITICAL

---

## Reinitialization & Account Lifecycle

### SOL-INIT-1 — `init_if_needed` without reinitialization guard?
- **Code smell:** Using `#[account(init_if_needed)]` on an instruction that should
  only operate on existing accounts.
- **Why it matters:** Attacker can call the instruction on an uninitialized account
  to reset state (e.g., resetting a reward counter to claim again).
- **Fix:** Use `#[account(init)]` for one-time initialization, or add explicit
  `require!(account.is_initialized)` checks.
- **Severity:** HIGH

### SOL-CLOSE-1 — Account closed without zeroing data?
- **Code smell:** Account lamports drained to zero (triggering garbage collection)
  but account data not explicitly zeroed. Or using `close` without ensuring the
  receiver is the expected destination.
- **Why it matters:** "Rent revival" attack — attacker transfers lamports back to
  the closed account, reviving it with stale data that's still valid (e.g., old
  authority or balance).
- **Fix:** Zero the account data bytes before closing, or use Anchor's `close`
  constraint which handles this. Validate the close destination.
- **Severity:** MEDIUM

---

## Arithmetic & Precision

### SOL-MATH-1 — Unchecked arithmetic in token amount calculations?
- **Code smell:** Using `+`, `-`, `*` without `checked_add`, `checked_sub`,
  `checked_mul`, or `checked_div`. Or not setting `overflow-checks = true` in
  `Cargo.toml`.
- **Why it matters:** Rust release mode wraps on overflow by default. A wrapped
  balance can enable infinite minting or balance inflation.
- **Fix:** Use `checked_*` methods, or set `overflow-checks = true` in the
  program's `Cargo.toml` (Anchor defaults this on, but verify).
- **Severity:** CRITICAL

### SOL-MATH-2 — Integer division rounding in share/token math?
- **Code smell:** Division before multiplication in share price or exchange rate
  calculations, or using integer division that truncates to zero.
- **Why it matters:** Precision loss compounds over many operations and can be
  exploited to extract value (dust attacks, share inflation).
- **Fix:** Multiply before divide, use `u128` intermediates for intermediate
  calculations, add minimum amount checks.
- **Severity:** HIGH

### Self-Referential / Endogenous Oracle
- [ ] Is the oracle price source **endogenous** to the protocol (derived from the
      protocol's own markets)? If so, an attacker can create a self-referential
      pricing loop where they manipulate the price on the very platform that uses it.
  - **Code smell:** Oracle reads from Serum/OpenBook markets that the protocol itself
    facilitates (spot or perp)
  - **Exploit:** Mango Markets ($114M) — $4M in buys on Mango's own markets moved
    the Pyth oracle price 23x, unlocking $114M in borrowing
  - **Mitigation:** Use external oracle sources (Pyth with confidence intervals,
    Chainlink), or implement TWAP with a window longer than the attack capital can
    sustain

### Missing Circuit Breakers
- [ ] Are there circuit breakers / deviation bounds that halt borrowing or liquidations
      when the oracle price moves more than X% within Y minutes?
  - **Code smell:** Oracle price accepted at face value regardless of magnitude of change
  - **Exploit:** Mango Markets — 2,300% price spike in 20 minutes with no safety trigger
  - **Mitigation:** Implement per-asset deviation bounds (e.g., halt if >50% move in
    10 minutes), pause borrowing on extreme moves, use Pyth confidence intervals

### Cross-Margin Without Asset Isolation
- [ ] Is collateral isolated by asset type, or can a single manipulated asset unlock
      borrowing against all other assets via cross-margin?
  - **Code smell:** Single collateral type (especially native/governance token) with
    high collateral weight and no per-asset borrowing caps
  - **Exploit:** Mango Markets — MNGO-PERP gains could borrow USDC, SOL, BTC, ETH
    with no per-asset caps, turning a $5M manipulation into $114M extraction
  - **Mitigation:** Per-asset collateral factors, isolation modes (limit what can be
    borrowed against volatile collateral), debt ceilings per collateral type

### CPI-Based Price Feed Validation
- [ ] When pricing collateral/assets via CPI to an external program, is the target program
  ID validated against a hardcoded known-good value?
  - **Code smell:** CPI to a user-supplied program account for pricing/exchange rate data
    without checking `program.key() == KNOWN_PROGRAM_ID`
  - **Exploit:** Loopscale ($5.8M) — attacker passed a malicious program as the RateX
    program, which returned inflated PT exchange rates, enabling undercollateralized loans
  - **Mitigation:** Hardcode expected program IDs for every pricing CPI; use Anchor
    `#[account(constraint = ratex_program.key() == RATEX_PROGRAM_ID)]` or explicit
    `require!()` checks before CPI

### Integration Consistency
- [ ] When adding support for a new collateral type or external integration, are all
  existing validation checks (program ID, account constraints, health check logic)
  consistently applied?
  - **Code smell:** New collateral adapter added without the same validation pattern as
    existing adapters (e.g., one type checks program ID, another doesn't)
  - **Exploit:** Loopscale — RateX PT integration (added March 27) lacked program ID
    validation that other PT token types had; the inconsistency was the vulnerability
  - **Mitigation:** Require that every new collateral type passes the same validation
    checklist; code review should diff new adapters against existing ones for missing checks

---

## Sysvar & System Program

### SOL-SYSVAR-1 — Unvalidated sysvar account address?
- **Code smell:** Accepting a `Rent`, `Clock`, or other sysvar as an `AccountInfo`
  without checking `is_sysvar_account_id()`.
- **Why it matters:** Attacker passes a fake sysvar account with manipulated
  values (e.g., fake clock to bypass time-locks).
- **Fix:** Use Anchor's `Sysvar<'info, Clock>` type, or validate the address
  explicitly.
- **Severity:** HIGH

---

## References

- [sealevel-attacks](https://github.com/coral-xyz/sealevel-attacks) — canonical vulnerable/secure example pairs
- [Neodyme Security](https://neodyme.io/en/blog/solana-security/) — common Solana pitfalls
- [Anchor Constraints Docs](https://www.anchor-lang.com/docs/account-constraints)
- [Helius Solana Hacks History](https://www.helius.dev/blog/solana-hacks)

---

*Last updated: 2026-06-01. Items derived from post-mortem analysis of Loopscale, Cashio,
Mango Markets, and other Solana exploits.*
