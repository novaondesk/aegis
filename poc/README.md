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

Run one: `forge test --match-contract InflationAttack -vv`

## Adding a PoC (see ../AGENTS.md)
1. `src/Vulnerable<X>.sol` — minimal, intentionally-vulnerable repro. Comment the bug.
2. `src/Safe<X>.sol` — the mitigated version (proves the fix).
3. `test/<X>.t.sol` — `test_*_isExploited` (attack profits / invariant breaks) and
   `test_*_resistsAttack` (fixed version holds).
4. Link it from the matching `docs/exploits/<x>.md`.
