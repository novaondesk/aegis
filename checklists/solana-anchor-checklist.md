# Solana / Anchor Security Checklist

Walk this against any Anchor program during review. Each item is phrased as a
yes/no question + the code smell + a real exploit that justifies it.

Legend: 🤖 = an automated tool/rule can flag candidates · 👁 = needs human judgment.

---

## Account Validation 👁🤖

### Missing Signer Check
- [ ] Is every privileged action gated by a `Signer` constraint or `is_signer` check?
  - **Code smell:** `#[account(mut)]` without `Signer` on authority/admin accounts
  - **Exploit:** Unauthorized admin actions, fund drainage
  - **Mitigation:** Always use `#[account(mut, signer)]` or verify `ctx.accounts.authority.is_signer`

### Missing Owner Check
- [ ] Is every deserialized account verified to be owned by the expected program?
  - **Code smell:** `Account<'info, T>` without `has_one` or explicit owner check
  - **Exploit:** Account substitution attacks, data corruption
  - **Mitigation:** Use `#[account(owner = expected_program)]` or verify `account.owner == program_id`

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

## Integer Overflow / Underflow 🤖

### Rust Release Mode Wrapping
- [ ] Are all arithmetic operations checked for overflow in release mode?
  - **Code smell:** Direct `+`, `-`, `*` operations on balances/amounts
  - **Exploit:** Silent overflow in release mode → balance manipulation
  - **Mitigation:** Use `checked_add`, `checked_sub`, `checked_mul` or enable `overflow-checks = true`

### Precision Loss
- [ ] Is integer division used correctly with proper rounding direction?
  - **Code smell:** Division before multiplication, truncation favoring attacker
  - **Exploit:** Rounding errors accumulating to extract value
  - **Mitigation:** Multiply before divide, use checked math, round in protocol's favor

### Shift Overflow / MSB Truncation 🤖
- [ ] Are all bit-shift operations verified against actual boundary conditions, not just wrapped in a "checked" function?
  - **Code smell:** Custom `checked_shl`/`checked_shr` wrappers with hand-rolled masks; trusting "checked" without boundary tests
  - **Exploit:** Cetus AMM ($223M) — wrong constant in `checked_shlw` mask (`0xff...ff << 192` instead of `1 << 192`) allowed silent MSB truncation in liquidity math
  - **Mitigation:** Test checked-shift wrappers with `n = threshold`, `n = threshold-1`, `n = threshold+1`; in Rust prefer `checked_shl()` over `wrapping_shl()`; fuzz-test math libraries with extreme inputs

---

## Account Lifecycle 👁

### Reinitialization Attack
- [ ] Is `init_if_needed` used safely with proper state checks?
  - **Code smell:** `init_if_needed` without checking if account is already initialized
  - **Exploit:** Re-init to reset state, steal funds
  - **Mitigation:** Add `require!(!account.is_initialized, ErrorCode::AlreadyInitialized)`

### Account Closing / Revival
- [ ] Are closed accounts properly zeroed and marked as closed?
  - **Code smell:** Only transferring lamports without zeroing data
  - **Exploit:** Rent revival — attacker can resurrect "closed" accounts
  - **Mitigation:** Zero all data fields and set a `closed` flag before lamport transfer

### Account Data Matching
- [ ] Does the program verify account data matches expected values?
  - **Code smell:** Using accounts without checking stored values match expectations
  - **Exploit:** Substituting malicious accounts with different data
  - **Mitigation:** Explicit checks comparing account data to expected values

### Account Reloading
- [ ] Are accounts reloaded after CPI calls to reflect updated state?
  - **Code smell:** Using pre-CPI account state after CPI that modifies the account
  - **Exploit:** Stale data leading to incorrect calculations
  - **Mitigation:** Call `account.reload()` after CPI that modifies the account

---

## CPI Security 👁

### Arbitrary CPI Target
- [ ] Is the program ID for CPI calls validated against a known-good value?
  - **Code smell:** CPI to `ctx.accounts.target_program.key()` without validation
  - **Exploit:** Attacker passes malicious program as target
  - **Mitigation:** Hardcode expected program IDs or use Anchor CPI modules

### CPI Privilege Escalation
- [ ] Does the CPI call only pass necessary signer privileges?
  - **Code smell:** Passing all signers to CPI when only some are needed
  - **Exploit:** Unintended privilege escalation via CPI
  - **Mitigation:** Minimize signer seeds passed to CPI, use PDA signing

---

## PDA Security 👁

### PDA Sharing
- [ ] Are PDAs used for distinct purposes with unique seeds?
  - **Code smell:** Same PDA seed for different operations (e.g., staking + rewards)
  - **Exploit:** Cross-contamination of PDA authority
  - **Mitigation:** Use distinct seeds per operation (e.g., `["staking", user]` vs `["rewards", user]`)

### Seed Collisions
- [ ] Are PDA seeds designed to prevent collisions between different contexts?
  - **Code smell:** Short or ambiguous seeds that could map to same PDA
  - **Exploit:** PDA collision leading to unauthorized access
  - **Mitigation:** Include discriminators (user key, operation type) in seeds

---

## Sysvar / Oracle Spoofing 👁

### Sysvar Validation
- [ ] Are sysvar accounts (Clock, Rent, etc.) validated against their known addresses?
  - **Code smell:** Accepting any account as sysvar without address check
  - **Exploit:** Fake sysvar providing incorrect time/rent data
  - **Mitigation:** Use Anchor's built-in sysvar types which validate addresses

### Oracle Manipulation
- [ ] Is oracle data validated for freshness, source, and bounds?
  - **Code smell:** Using spot AMM prices or unvalidated oracle feeds
  - **Exploit:** Flash loan oracle manipulation (Mango Markets $114M)
  - **Mitigation:** Use TWAP, multiple sources, staleness checks, min/max bounds

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

---

## Signer Validation 👁

### Missing Signature Check
- [ ] Is every privileged operation verified to be signed by the appropriate authority?
  - **Code smell:** Authority check without `is_signer` verification
  - **Exploit:** Unauthorized operations by non-signers
  - **Mitigation:** Always verify `authority.is_signer` for privileged operations

---

## Rust-Specific 👁

### Unsafe Code
- [ ] Is `unsafe` code used only when necessary and thoroughly audited?
  - **Code smell:** Unnecessary `unsafe` blocks
  - **Exploit:** Memory safety violations, undefined behavior
  - **Mitigation:** Minimize `unsafe`, document safety invariants

### Panic Handling
- [ ] Are potential panic scenarios (unwrap, division by zero, index out of bounds) handled?
  - **Code smell:** `.unwrap()` without error handling, potential division by zero
  - **Exploit:** Program crashes, denial of service
  - **Mitigation:** Use `?` operator, handle errors gracefully, validate inputs

---

## Sources
- [Helius: Hitchhiker's Guide to Solana Program Security](https://www.helius.dev/blog/a-hitchhikers-guide-to-solana-program-security)
- [Neodyme: Solana Security Workshop](https://neodyme.io/blog/solana-security/)
- [Anchor Framework Security Best Practices](https://www.anchor-lang.com/docs/security)
- [Sealevel Attacks (Canonical Examples)](https://github.com/coral-xyz/sealevel-attacks)
- [Nomos: Anchor Framework Security Limits](https://nomoslabs.io/blog/anchor-framework-security-limits-remaining-risks)
- [VultBase: Anchor Program Security](https://www.vultbase.com/articles/anchor-program-security-solana)
- [Medium: Solana Security in Anchor V2 Era](https://medium.com/@FrankCastleAudits/solana-security-in-the-anchor-v2-era-where-the-bugs-moved-3050adc39412)
- [AnchorScan: AnchorLang Security Best Practices 2026](https://anchorscan.ca/blog/anchorlang-security-best-practices-for-2026.html)
