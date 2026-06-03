# General engines — finding bugs the catalog doesn't list (REVIEW phase)

The catalog catches *known* exploits. These two general engines catch *novel* ones by
reasoning about the target's own structure. Adapted from QuillShield's Semantic State
Protocol. Run them in Phase 3, after the sweep.

---

## Engine A — State-invariant inference

**Premise:** well-designed contracts maintain mathematical relationships between state
variables. A function that updates one side without the other breaks the invariant →
exploitable accounting drift (the root cause behind the biggest DeFi hacks).

### Step 1 — cluster related state variables
For each pair (A, B), `CoMod(A,B) = |fns modifying both| / |fns modifying either|`.
`CoMod > 0.6` ⇒ likely related. (e.g. `mint`/`burn` co-modify `totalSupply` & `balances`.)

### Step 2 — infer the invariant type
Match deltas across the functions that touch the cluster:

| Type | Shape | Found in |
|---|---|---|
| **Sum / aggregation** | `total = Σ parts` | ERC20 supply, staking, vault shares |
| **Conservation** | `total = available + locked` | treasuries, vesting, pools |
| **Ratio** | `k = x·y`, `price = assets/shares` | AMMs, vault pricing, collateralization |
| **Monotonic** | `new ≥ old` | nonces, timestamps, accumulated rewards |
| **Synchronization** | "if A changes, B must" | deposit/mint, collateral/borrow-power |

Invariant confidence = `|fns preserving I| / |fns modifying I's vars|`. ≥90% STRONG,
70–89% MODERATE, <70% weak (don't over-trust).

### Step 3 — find violators
For each inferred invariant `I` and each function `F` touching its vars: does there exist a
reachable state where `I` holds before `F` and breaks after? That `F` is the candidate.
Confirm with a PoC in Phase 5.

### Quick checklist
- [ ] Does every `balances` mutation also update `totalSupply` (or provably net-zero it)?
- [ ] Does every move between `available`/`locked` preserve `total = available + locked`?
- [ ] Does every swap preserve `k = reserveA·reserveB` (minus declared fee)?
- [ ] Do aggregate counters stay synced with their per-user mappings?
- [ ] Are monotonic vars (nonces, timestamps, indexes) ever decremented?

---

## Engine B — Semantic-guard consistency

**Premise — "a contract is its own specification":** if the codebase consistently applies a
guard (a modifier, `require`, pause check, nonce bump, reentrancy lock) to an operation,
any function performing that operation **without** the guard is a likely bug — even when no
catalog entry names it.

### Procedure
1. **Inventory guards.** List every modifier / `require` / check and the operation it
   protects (state write, transfer, mint, privileged action, external call).
2. **Build the consistency table.** For each sensitive operation, list the functions that
   perform it and whether each applies the guard the others do.
3. **Flag the outliers.** A function missing a guard its siblings apply is the finding.
   Common shapes:
   - missing `onlyOwner`/role on one privileged setter among many
   - one state-changing path that skips the `nonReentrant` lock peers use
   - a withdraw that omits the pause/health check the others enforce
   - an init/upgrade path lacking the `initializer`/`whenNotPaused` guard
4. **Rank by combination** (see severity matrix): a missing guard that *also* breaks a
   state invariant (Engine A) is CRITICAL.

### Severity combination (with Engine A)
| Missing guard? | Breaks invariant? | Severity |
|---|---|---|
| yes | yes | **Critical** |
| yes | no | **High** |
| no | yes | **High** |
| no | no | Low/Info |

### Rationalizations to reject
- "That function is admin-only anyway" → verify the modifier is actually present on *this*
  function, not just its neighbors.
- "The check is done in the caller" → confirm every caller path; external entry points may
  reach it directly.
- "It's an emergency function, guards slow it down" → emergency paths that skip guards
  create worse emergencies.
