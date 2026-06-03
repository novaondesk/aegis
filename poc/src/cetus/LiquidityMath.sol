// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// Models Cetus's `checked_shlw` — a guarded left-shift-by-64 used in CLMM liquidity
/// math. Critically, on EVM (as on Move) the `<<` operator is MODULAR: it silently wraps
/// instead of reverting, so the explicit overflow guard is the only protection. A wrong
/// boundary constant in that guard is the whole bug.
///
/// The real fault: the guard used `0xffffffffffffffff << 192` (≈ 2^256 − 2^192) as the
/// overflow boundary instead of `1 << 192` (2^192). Values in [2^192, 2^256 − 2^192)
/// passed the check and then truncated on the shift.
///
/// See docs/exploits/cetus-amm-overflow-2025-05-22.md
library LiquidityMath {
    // WRONG: lets any n below ~2^256 through; n >= 2^192 still overflows `<< 64`.
    uint256 internal constant WRONG_MASK = uint256(type(uint64).max) << 192; // ~2^256 − 2^192

    // CORRECT: n must be < 2^192 for `n << 64` not to overflow 256 bits.
    uint256 internal constant CORRECT_MASK = (uint256(1) << 192) - 1; // 2^192 − 1

    /// VULNERABLE checked_shlw: wrong boundary. n = 2^192 passes, then `n << 64` == 2^256
    /// wraps to 0 — the silent truncation that collapsed the required deposit to ~nothing.
    function shlw64Vulnerable(uint256 n) internal pure returns (uint256) {
        require(n <= WRONG_MASK, "overflow"); // boundary too high to catch the real overflow
        return n << 64; // modular shift — wraps for n >= 2^192
    }

    /// SAFE checked_shlw: correct boundary rejects anything that would overflow the shift.
    function shlw64Safe(uint256 n) internal pure returns (uint256) {
        require(n <= CORRECT_MASK, "overflow");
        return n << 64;
    }
}
