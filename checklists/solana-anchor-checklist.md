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
