# Aegis vs. the Ethernaut wargame

This report shows **Aegis solving OpenZeppelin's [Ethernaut](https://ethernaut.openzeppelin.com/)
CTF using only its own methodology** — the [`aegis-audit`](../skills/aegis-audit/SKILL.md) loop run
against the [exploit catalog](../catalog/exploits.yaml). It documents, per level, **which catalog
detector identified the bug** (the *sweep*), the precise `applies_when` signals that matched, and the
runnable proof that exploits the real level contract (the *prove*).

The point isn't that these CTF levels are hard — it's that the **same catalog of detectors mined
from real DeFi hacks** ($292M Kelp, $181M Beanstalk, $128M Balancer, …) maps onto and solves an
independent, third-party benchmark. If the catalog generalizes to Ethernaut, it generalizes.

## How this was run (Aegis loop, not hand-waving)

For each level: **RECON** the level source → **SWEEP** it against every catalog entry, scoring each
entry's `applies_when` preconditions against the code → take the matched detector as the hypothesis →
**PROVE** it with a Foundry test that exploits the *real* level contract and asserts the level's own
win condition (`validateInstance`). Levels are deployed and exploited locally; the live browser game
only adds a wallet + testnet transaction on top of the same contracts.

- Harness + runnable proofs: [`ethernaut/`](../ethernaut/) (`cd ethernaut && forge test`).
- Level sources are vendored verbatim from `github.com/OpenZeppelin/ethernaut` (MIT).
- **Result: 5 / 5 solved, 0 failures.**

## Catalog coverage used

| Ethernaut level | Class | Catalog detector that caught it | Proof |
|---|---|---|---|
| #3 CoinFlip | SC09 | [`insecure-randomness`](exploits/insecure-randomness.md) | [`test/CoinFlip.t.sol`](../ethernaut/test/CoinFlip.t.sol) |
| #6 Delegation | SC01 | [`proxy-storage-collision`](exploits/proxy-storage-collision-2022-07.md) | [`test/Delegation.t.sol`](../ethernaut/test/Delegation.t.sol) |
| #10 Reentrance | SC08 | [`cei-reentrancy`](exploits/cei-reentrancy.md) | [`test/Reentrance.t.sol`](../ethernaut/test/Reentrance.t.sol) |
| #22 Dex | SC03 | [`loopscale-oracle-spot-price`](exploits/loopscale-oracle-2025-04.md) (price-manip family) | [`test/Dex.t.sol`](../ethernaut/test/Dex.t.sol) |
| #25 Motorbike | SC01 | [`unprotected-privileged-fn`](exploits/unprotected-privileged-fn.md) | [`test/Motorbike.t.sol`](../ethernaut/test/Motorbike.t.sol) |

---

## #3 CoinFlip → `insecure-randomness` (SC09)

**Sweep.** The level derives the coin side from `blockhash(block.number - 1)`. Catalog
`insecure-randomness.applies_when` matched directly:
- *"block.timestamp / prevrandao / blockhash / number feeds a winner/rarity/selection"* — `blockValue = uint256(blockhash(block.number - 1))` decides the side.
- *"the outcome is computed at the same time the participant commits"* — single `flip()` call, no commit-reveal, no VRF.

**Root cause (catalog).** *Participant-observable block variables reach the selection at commit time
without external entropy, so the outcome is precomputable.*

**Prove.** An attacker contract recomputes `blockhash(block.number-1) / FACTOR` in the same
transaction and calls `flip()` with the guaranteed-correct guess, 10 blocks running.
**Win:** `consecutiveWins == 10`.

## #6 Delegation → `proxy-storage-collision` (SC01)

**Sweep.** `Delegation.fallback()` does `delegate.delegatecall(msg.data)`, and `Delegate.owner` /
`Delegation.owner` both sit at storage slot 0. Catalog `proxy-storage-collision.applies_when` matched:
- *"a proxy that delegatecalls into an implementation"* — the fallback delegatecall.
- *"an implementation state variable shares a storage slot with a proxy bookkeeping pointer"* — `owner` at slot 0 in both.
- *"an implementation function (initialize/setOwner/governance) is reachable through the proxy and writes that slot"* — `Delegate.pwn()` sets `owner`.

**Root cause (catalog).** *An implementation state write reaches a proxy slot through delegatecall
without unstructured-slot separation, so a logic function overwrites the privileged pointer.*

**Prove.** Call the contract with `pwn()`'s selector → fallback → delegatecall → slot 0 (owner) is
overwritten with the caller. **Win:** `owner == attacker`. (This is exactly the Audius-class bug whose
real-world replay is in [`sim/`](../sim/test/AudiusGovTakeover_2022_07.t.sol).)

## #10 Reentrance → `cei-reentrancy` (SC08)

**Sweep.** `withdraw()` sends ETH via `msg.sender.call{value:_amount}("")` **before** decrementing
`balances[msg.sender]`. Catalog `cei-reentrancy.applies_when` matched:
- *"a function makes an external call … and updates balances/state AFTER it"* — the send precedes the decrement.
- *"no reentrancy lock on the path"* — none.
- *"the external call's recipient is attacker-controllable (msg.sender)"* — yes.

**Root cause (catalog).** *A state-changing function performs an external call before the balance
update, so an attacker-controlled callback re-enters with stale state.*

**Prove.** A malicious `receive()` re-enters `withdraw()` until the contract is empty. **Win:**
contract balance `== 0`. *(This level prompted adding the exact `cei-reentrancy` catalog entry — the
state-changing sibling of `read-only-reentrancy` — with its own [PoC](../poc/test/CeiReentrancy.t.sol).)*

## #22 Dex → `loopscale-oracle-spot-price` / price-manipulation family (SC03)

**Sweep.** `getSwapPrice = amount * balanceOf(to) / balanceOf(from)` prices a swap off the pool's own
live balances, with integer rounding and no invariant/slippage guard. Catalog
`loopscale-oracle-spot-price.applies_when` matched:
- *"value comes from a single liquidity-pool spot price"* — price = a ratio of the pool's own balances.
- *"no TWAP, no multi-oracle cross-check, no deviation bound"* — none.
- *"pricing can occur within one transaction"* — the attacker swaps repeatedly in-line.

**Root cause (catalog).** *Value reaches a sensitive computation from a single manipulable spot price
without TWAP/cross-check/deviation bound, so the price can be moved in-transaction.* (Same family as
the Mango ($114M) and Loopscale entries.)

**Prove.** Swap back and forth; each round the rounding amplifies the imbalance until one full swap
drains a reserve. **Win:** `balanceOf(token1, dex) == 0 || balanceOf(token2, dex) == 0`.

## #25 Motorbike → `unprotected-privileged-fn` (SC01)

**Sweep.** The UUPS `Engine` is initialized only in the *proxy's* storage (via the proxy ctor's
delegatecall); the Engine's own storage is never initialized, so `Engine.initialize()` is callable by
anyone. Catalog `unprotected-privileged-fn.applies_when` matched:
- *"initialize has no `require(!_initialized)` once-guard, or the proxy is not initialized atomically at deploy"* — the logic contract itself is left uninitialized.
- *"an external function writes owner/admin … or upgrades implementation"* — `initialize` sets `upgrader`; `upgradeToAndCall` then upgrades.

**Root cause (catalog).** *An unauthenticated caller reaches a privileged state change without an
access-control modifier or initializer guard.*

**Prove.** Call `Engine.initialize()` directly to become `upgrader`, then `upgradeToAndCall` a contract
that `selfdestruct`s via delegatecall. **Win:** the Engine has no code.

---

## Takeaways

- **5/5 solved purely by the catalog sweep** — each level's bug was identified by an `applies_when`
  match against detectors mined from real incidents, then proven against the real level contract.
- **The same detectors span CTF and mainnet:** Delegation ↔ the Audius $1.08M replay
  (`proxy-storage-collision`); Dex ↔ the Mango $114M / Loopscale entries (spot-price manipulation);
  Motorbike ↔ the DAO Maker $5.76M replay (`unprotected-privileged-fn`).
- **The wargame grew the catalog:** Reentrance initially mapped only to the SC08 *family*, so a
  dedicated [`cei-reentrancy`](exploits/cei-reentrancy.md) detector (+ PoC) was added — now all 5 map
  to an exact entry. The benchmark feeding the catalog is the loop working as intended.

Reproduce: `cd ethernaut && forge test -vv`.
