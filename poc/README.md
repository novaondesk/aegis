# poc/ — Runnable Foundry PoCs

Each exploit deep-dive lands here as **vulnerable contract + safe contract + exploit
test**, so a finding is provable, not just asserted.

## Setup
```bash
cd poc
forge install foundry-rs/forge-std   # lib/ is gitignored; run once after clone
forge build
forge test -vv
```

## Current PoCs
| Test | Class | Demonstrates |
|------|-------|--------------|
| `test/InflationAttack.t.sol` | SC07/SC02 | ERC-4626 first-depositor share-inflation: attacker steals victim's rounding remainder; virtual-offset fix neutralizes it. |
| `test/ReadOnlyReentrancy.t.sol` | SC08 | Read-only reentrancy (Curve `get_virtual_price` class): inflated view price mid-callback lets attacker over-borrow from a consumer; CEI fix neutralizes it. |
| `test/BeanstalkGovernance.t.sol` | SC02/SC04 | Governance flash-loan ($181M): real-time voting power lets a zero-capital flash loan reach supermajority and `emergencyCommit`-drain the treasury in one tx; snapshot-at-proposal-creation neutralizes it. |
| `test/RheaSlippage.t.sol` | SC02/SC07 | Multi-hop swap slippage ($18.4M): summing every hop's `minAmountOut` inflates the validated minimum, so the margin engine credits phantom collateral; terminal-only minimum + post-swap validation neutralizes it. |
| `test/BalancerRounding.t.sol` | SC07 | Balancer V2 rounding ($128M): inconsistent directional rounding lets dust swaps deflate the pool invariant `D`; rounding against the trader holds `D` non-decreasing. |
| `test/CashioInfiniteMint.t.sol` | SC05/SC02 | Cashio infinite-mint ($52.8M, EVM model): collateral validated only relatively mints unlimited stablecoin from fakes; anchoring the mint to a trusted token neutralizes it. |
| `test/CetusOverflow.t.sol` | SC07/SC09 | Cetus overflow check ($223M, EVM model): a wrong-boundary guard lets `2^192` slip past and `<< 64` truncate, so a huge position costs ~0; the correct boundary reverts. |
| `test/LoopscaleOracle.t.sol` | SC03/SC02 | Loopscale spot-price ($5.8M, EVM model): collateral priced off a thin pool's spot price is skewed in-tx for a ~100× over-borrow; a manipulation-resistant reference price holds. |
| `test/LoopscaleCpi.t.sol` | SC03/SC05 | Loopscale unvalidated CPI ($5.8M, EVM model): reading a rate from a borrower-supplied provider lets a spoof inflate it ~1000×; pinning a trusted provider neutralizes it. |
| `test/MangoOracle.t.sol` | SC03/SC02 | Mango oracle manipulation ($114M, EVM model): a thin token at 100% weight, priced off the market the attacker spikes, drains the reserve; a deviation circuit breaker + per-asset cap holds. |
| `test/CTokenInflation.t.sol` | SC07/SC02 | cToken empty-market exchange-rate inflation (~$7M+): first minter donates underlying to inflate `cash/supply`, a victim's mint rounds to zero cTokens and is siphoned; seeded dead shares + zero-mint guard hold. |
| `test/ApprovalDrain.t.sol` | SC05/SC01 | Router arbitrary-call approval drain (Socket/Seneca): a router forwarding `target.call(data)` while holding approvals lets an attacker call `transferFrom(victim,attacker)`; an adapter allow-list holds. |
| `test/ProxyCollision.t.sol` | SC01 | Upgradeable-proxy storage-slot collision ($6M, Audius-class): a sequential-slot admin overlaps the impl's slot-0 var, so `initialize()` overwrites admin; EIP-1967 unstructured slots hold. |
| `test/SignatureReplay.t.sol` | SC01 | Signature replay + ecrecover malleability: a no-nonce/no-domain signature is replayed and an `n−s` twin is a second valid sig; EIP-712 + per-account nonce + low-s check hold. |
| `test/UnprotectedPrivileged.t.sol` | SC01 | Missing access control (PAID-class): ungated `mint` + re-callable `initialize` let anyone print supply / seize ownership; `onlyOwner` + a one-shot initializer hold. |
| `test/InsecureRandomness.t.sol` | SC09 | Predictable on-chain randomness: an attacker recomputes a block-var draw and only enters winning blocks; externally-supplied VRF randomness holds. |
| `test/WeirdErc20Accounting.t.sol` | SC02 | Fee-on-transfer / weird-ERC20 accounting: crediting the requested amount on a fee-on-transfer token makes `sum(credited) > balance` and shorts late withdrawers; crediting the measured balance delta holds. |
| `test/IncorrectRewardAccounting.t.sol` | SC02 | MasterChef reward-debt desync: a harvest that pays `pending` without advancing `rewardDebt` is re-harvestable and drains the pool; checkpointing `rewardDebt` holds. |
| `test/UnverifiedCallback.t.sol` | SC05/SC01 | Unverified flash-loan/external callback: an `onFlashLoan` callback with no `msg.sender`/`initiator` check is called directly to drain working capital; caller + initiator checks hold. |
| `test/BridgeNoCodeToken.t.sol` | SC02 | Bridge no-code-token deposit (Qubit $80M): a low-level `transferFrom` to a codeless address returns success, so the bridge credits a deposit that never moved; a code-existence + allow-list check holds. |
| `test/FirstDepositSkim.t.sol` | SC07 | AMM-pair first-deposit skim (UniV2-fork): no `MINIMUM_LIQUIDITY` lock lets the first LP donate to inflate share price so a later LP mints zero LP and is skimmed; locking `MINIMUM_LIQUIDITY` + `require(liquidity>0)` hold. |

Run one: `forge test --match-contract InflationAttack -vv`

## Adding a PoC (see ../AGENTS.md)
1. `src/Vulnerable<X>.sol` — minimal, intentionally-vulnerable repro. Comment the bug.
2. `src/Safe<X>.sol` — the mitigated version (proves the fix).
3. `test/<X>.t.sol` — `test_*_isExploited` (attack profits / invariant breaks) and
   `test_*_resistsAttack` (fixed version holds).
4. Link it from the matching `docs/exploits/<x>.md`.
