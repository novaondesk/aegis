# 2026-06-01 — Cetus AMM Deep-Dive

**Agent:** Nova
**Duration:** ~20 min
**Task:** Case study — Cetus AMM overflow exploit ($223M)

## What I did

Researched the Cetus Protocol exploit (May 22, 2025) from primary security researcher
post-mortems (Dedaub, Halborn, Rekt.news). Created a full case study following the
repo template.

## Key findings

### Root cause
Single wrong constant in `checked_shlw` function within the `integer-mate` math library:
- **Intended mask:** `1 << 192` (smallest value that overflows on `<< 64`)
- **Actual mask:** `0xffffffffffffffff << 192` (= `2^256 - 2^192`, way too large)
- This let values in `[2^192, 2^256 - 2^192)` pass the overflow check undetected
- The `<< 64` shift then silently truncated the MSBs (Move bit-shifts don't abort)
- Result: `get_delta_a()` returned ~1 token instead of a proportional amount

### Attack mechanics
1. Flash loan → open narrow tick position [300000, 300200]
2. Supply crafted `liquidity ≈ 2^113` with 1 token
3. Overflow collapses token requirement to 1
4. Remove liquidity → drain pool → repay flash loan
5. Repeated across multiple pools → $223M total

### Recovery
- Sui validators froze $162M of stolen funds
- Community voted to return frozen funds via multisig (Cetus + OtterSec + Sui Foundation)
- All affected users fully reimbursed

### Audit trail (concerning)
- OtterSec found identical issue in Aptos version (early 2023) — fixed correctly
- Port to Sui reintroduced the bug with different mask
- Three audits (OtterSec, MoveBit, Zellic) did not catch the regression
- Math library may have been out of scope for some audits

## Files modified

| File | Change |
|------|--------|
| `docs/exploits/cetus-amm-overflow-2025-05-22.md` | **NEW** — full case study |
| `checklists/solana-anchor-checklist.md` | Added "Shift Overflow / MSB Truncation" item |
| `checklists/master-checklist.md` | Added bit-shift overflow item to SC07 |
| `docs/exploits/2026-recent-exploits.md` | Marked Cetus deep-dive as done |

## Cross-chain lesson for Solana

The same pattern applies to Rust/Solana:
- `wrapping_shl` / `wrapping_shr` silently truncate (like Move `<<`)
- `checked_shl` / `checked_shr` return `Option` (safe, but must be used correctly)
- Any custom bit-manipulation in math libraries deserves boundary testing
- Anchor programs using `u128`/`u256` math libraries should be audited for this

## Next actions

- [ ] Balancer V2 ComposableStablePool rounding deep-dive
- [ ] Create a Foundry PoC sketching the overflow pattern (EVM analog)
- [ ] Add semgrep rule for `wrapping_shl`/`wrapping_shr` in Rust/Solana code
- [ ] Research Solana detection tools (cargo-geiger, soteria)
