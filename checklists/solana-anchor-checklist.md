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
