# 2026-06-01 — Read-only reentrancy deep-dive (autonomous)

## What we did
- Second runnable EVM deep-dive: **read-only reentrancy** (Curve `get_virtual_price` class).
- `poc/src/readonly/`: `ReentrantPool` (vulnerable: reserve updated AFTER the ETH send),
  `SafePool` (CEI fix), `LendingMarket` (consumer that prices LP collateral via the
  pool's view). `poc/test/ReadOnlyReentrancy.t.sol` — **both tests pass**:
  - Vulnerable: mid-callback `pricePerShare` inflates 1e18→~1.667e18; attacker borrows
    80 ETH against collateral truly worth 50 ETH; market drained 80 ETH (~30 bad debt).
  - Safe (CEI): reentrant over-borrow reverts UNDERCOLLATERALIZED.
- `docs/exploits/read-only-reentrancy.md` written; linked from master-checklist SC08;
  added to `poc/README.md`.

## Why it matters
This is the canonical **tool-blind, cross-contract** bug: `nonReentrant` on state-
changing functions doesn't protect views, and single-contract scanners can't see the
pool↔consumer interaction. Exactly the human-judgment territory the suite targets.

## Next
- [ ] Foundry invariant: probe `pricePerShare()` from inside a malicious receiver.
- [ ] Add a manual-review prompt (not a precise semgrep rule) for "external value call
      not at end of a function whose storage feeds a view oracle."
- [ ] Continue: Balancer V2 precision-loss deep-dive (well-motivated by Heimdallr).
