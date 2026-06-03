# Mitigation patterns — fix per vuln class, with a proof to copy

Each row is the minimal fix that restores the broken invariant, the catalog entry it
defends, and the existing `Safe<X>` PoC that *proves* the fix (re-run its test against the
patch). Don't invent a fix when one of these applies — adapt the proven one.

| Class | Broken invariant | Minimal fix | Catalog entry | Proof to copy |
|---|---|---|---|---|
| SC07 vault precision | share price fair between depositors | virtual offset / dead-shares floor on first mint; never price off raw `balanceOf(this)` | `erc4626-inflation` | `poc/test/InflationAttack.t.sol` (Safe vault) |
| SC08 read-only reentrancy | view price not mid-callback transient | reentrancy lock on the view path; follow CEI; don't consume a pool view as an oracle mid-callback | `read-only-reentrancy` | `poc/test/ReadOnlyReentrancy.t.sol` |
| SC07 scaled-balance rounding | invariant D non-decreasing on round-trip | round **against the trader** consistently (input up / output down); add a dust/precision floor | `balancer-v2-rounding` | `poc/test/BalancerRounding.t.sol` (Safe pool) |
| SC05 account validation | every mint backed by a trusted-mint collateral | anchor the collateral account to a hardcoded/known mint/program (`address =` / `has_one`), not a relative check | `cashio-infinite-mint` | `poc/test/CashioInfiniteMint.t.sol` (Safe minter) |
| SC07 overflow/shift | no input silently truncates | correct overflow boundary (`1 << N`, not a hand-written mask); bound liquidity/amount inputs | `cetus-amm-overflow` | `poc/test/CetusOverflow.t.sol` (Safe shlw) |
| SC03 spot-price oracle | price unmovable within one tx | manipulation-resistant price: TWAP / multi-source median / staleness + deviation bounds | `loopscale-oracle-spot-price` | `poc/test/LoopscaleOracle.t.sol` (Safe market) |
| SC05/SC03 unvalidated CPI | all cross-program calls hit a known id | pin the program/contract address to a trusted constant; reject borrower-supplied targets | `loopscale-ratex-cpi` | `poc/test/LoopscaleCpi.t.sol` (Safe market) |
| SC03 collateral oracle design | borrow power bounded by real liquidity | per-asset borrow caps + sub-100% collateral weight + price-deviation circuit breaker | `mango-oracle-manipulation` | `poc/test/MangoOracle.t.sol` (Safe cross-margin) |
| SC02/SC04 governance flash-loan | approval reflects pre-proposal stake | snapshot voting power at proposal creation; timelock between execution and asset moves | `beanstalk-governance-flashloan` | `poc/test/BeanstalkGovernance.t.sol` (Safe gov) |
| SC02/SC07 multi-hop slippage | validated min == actual terminal output | use only the terminal hop's min; re-check actual output post-swap; whitelist pools | `rhea-finance-slippage` | `poc/test/RheaSlippage.t.sol` (Safe engine) |

## How to prove a fix (the rule)
1. Keep the finding's `Vulnerable<X>` and `test_*_isExploited` unchanged.
2. Implement `Safe<X>` with the fix above (or patch the target in place).
3. Add/confirm `test_*_resistsAttack`: the same attack sequence must now revert or leave
   the invariant intact.
4. `cd poc && forge test --match-contract <X> -vv` — both tests green = fix proven.

## Defense-in-depth layers (after the fix, not instead)
- **Foundry invariant tests** in `tools/foundry-invariants/` for each restored invariant
  (the property the exploit broke) — catches regressions and variants.
- **Circuit breakers / caps:** per-asset borrow caps, oracle deviation bounds, withdraw
  rate limits, pausability.
- **Monitoring:** events on privileged actions; off-chain alerting on invariant drift.
- **Process:** timelock on upgrades + privileged setters; two-step ownership; multisig.
