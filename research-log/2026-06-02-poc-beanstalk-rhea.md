# Research Log — 2026-06-02 — PoCs: Beanstalk governance + Rhea slippage

## Done
- Ported the two newest `studied` catalog entries to runnable Foundry PoCs (vulnerable + safe + exploit test), taking the catalog to 4/10 coded.
- **Beanstalk governance flash-loan** (`poc/test/BeanstalkGovernance.t.sol`):
  - `src/beanstalk/Silo.sol` — deposit→Roots, stamps each deposit with `block.timestamp` so `rootsOfAt(who, asOf)` can measure snapshot vs real-time voting power.
  - `src/beanstalk/Governance.sol` — `GovernanceBase` holding the treasury; `VulnerableGovernance` reads `rootsFor/totalRoots` from current storage, `SafeGovernance` measures against the proposal-creation snapshot. One overridden function is the whole bug.
  - Test: a zero-capital `GovAttacker` flash-loans an overwhelming Silo deposit and, in one tx, votes → `emergencyCommit` → drains the full 1M treasury. Vulnerable drains; safe reverts `no supermajority` (flash-loaned Roots = 0 at snapshot).
- **Rhea Finance slippage** (`poc/test/RheaSlippage.t.sol`):
  - `src/rhea/SwapRoute.sol` (types), `src/rhea/Router.sol` (fabricated-pool stand-in returning a tiny real output), `src/rhea/MarginEngine.sol` (`Vulnerable` sums every hop's `minAmountOut` and credits that without checking actual output; `Safe` trusts only the terminal minimum + post-swap validation).
  - Test: poisoned 6-hop route inflates the validated minimum to 1.2M for a sliver of collateral → vulnerable engine credits phantom collateral and the attacker withdraws the whole reserve; safe engine reverts `slippage: output below minimum`.
- Flipped both catalog entries `studied → coded` with `poc`/`poc_cmd`; linked the PoC from each case study; updated `poc/README.md`, top `README.md` (status column + "4 with coded PoCs").
- Full PoC suite green: `forge test` → 8 passed / 0 failed across 4 suites.

## Takeaways
- Both NEAR/diamond-specific incidents reduce cleanly to a single EVM invariant, which is exactly what makes them catalog detectors: Beanstalk = "voting power must be snapshotted at proposal creation"; Rhea = "validated minimum must equal terminal output, and actual must be re-checked post-swap".
- Modelling the flash loan as an in-callback `attack()` keeps the "zero capital, one atomic tx" property explicit rather than hand-waved.
- The `forge lint` ERC20-unchecked-transfer warning is cosmetic here (matches existing MockERC20 PoC style); not a test failure.

## Next
- [ ] Port a `studied` Solana entry (Cashio / Mango / Loopscale) to its native Anchor harness — the EVM-model trick doesn't carry over as cleanly for account-validation bugs.
- [ ] Cetus (Move) overflow PoC.
- [ ] Balancer V2 rounding — closest remaining EVM `studied` entry to code.
