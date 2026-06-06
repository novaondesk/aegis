# Aegis vs. the Ethernaut wargame

Aegis solves **37 of the 40 levels** of OpenZeppelin's [Ethernaut](https://ethernaut.openzeppelin.com/)
CTF using its own methodology — the [`aegis-audit`](../skills/aegis-audit/SKILL.md) loop run against the
[exploit catalog](../catalog/exploits.yaml). For each level: **RECON** the source → **SWEEP** it
against the catalog → **PROVE** by exploiting the real level contract and asserting the level's own
win condition. Every level is deployed and exploited locally in Foundry ([`ethernaut/`](../ethernaut/),
`cd ethernaut && forge test` → **37 passing**).

> Ethernaut has grown past the classic 31 — there are now **40 playable levels**. The first 31 are all
> solved (below); the 9 newer ones are evaluated in [§ The newer levels](#the-newer-levels-3240), with
> 3 solved in-harness (Impersonator, Forger, BetHouse) and 6 deferred (infra-heavy / deeper puzzles).

Two things come out of this:
1. **Validation** — the catalog detectors mined from real hacks ($292M Kelp, $181M Beanstalk, …) map
   onto and solve an independent third-party benchmark.
2. **Gaps surfaced** — the levels Aegis solves with *general techniques* (no matching detector) are an
   honest to-do list of detector classes worth adding (DoS, forced-ether, info-exposure, …).

## Full coverage (31 / 31)

| # | Level | Class | Caught by catalog detector | Solve |
|---|-------|-------|----------------------------|-------|
| 1 | Fallback | SC01 | `unprotected-privileged-fn` (family) | unguarded `receive` grants ownership |
| 2 | Fallout | SC01 | **`unprotected-privileged-fn`** | misspelled "constructor" is a public fn |
| 3 | CoinFlip | SC09 | **`insecure-randomness`** | predict `blockhash`-based RNG |
| 4 | Telephone | SC01 | *gap: tx.origin auth* | call via a contract (`tx.origin != msg.sender`) |
| 5 | Token | SC09 | *gap: integer underflow* | unchecked `-` underflows balance |
| 6 | Delegation | SC01 | **`proxy-storage-collision`** | `delegatecall` `pwn()` writes slot 0 |
| 7 | Force | — | *gap: forced ether* | `selfdestruct` pushes ETH |
| 8 | Vault | — | *gap: info exposure* | read the "private" storage slot |
| 9 | King | — | *gap: DoS* | become king with a reverting `receive` |
| 10 | Reentrance | SC08 | **`cei-reentrancy`** | re-enter `withdraw` before the decrement |
| 11 | Elevator | SC02 | *gap: untrusted interface* | `isLastFloor` returns false then true |
| 12 | Privacy | — | *gap: info exposure* | read `data[2]` from storage slot 5 |
| 13 | GatekeeperOne | SC01 | *gap: multi-gate* | brute-force gas + craft the gate key |
| 14 | GatekeeperTwo | SC01 | *gap: multi-gate* | call from a constructor (`extcodesize==0`) |
| 15 | NaughtCoin | SC02 | *gap: incomplete restriction* | timelock skips `transferFrom` |
| 16 | Preservation | SC01 | **`proxy-storage-collision`** | library `delegatecall` rewrites slots |
| 17 | Recovery | — | *gap: address recovery* | recompute the CREATE address, `destroy` |
| 18 | MagicNumber | — | *gap: raw bytecode* | hand-write a 10-byte contract |
| 19 | AlienCodex | SC09 | *gap: storage/array underflow* | underflow `length` to overwrite owner |
| 20 | Denial | — | *gap: DoS (gas)* | partner consumes all forwarded gas |
| 21 | Shop | SC02 | *gap: untrusted interface* | `price()` returns high then low |
| 22 | Dex | SC03 | **`loopscale-oracle-spot-price`** (family) | swap to skew the balance-ratio price |
| 23 | DexTwo | SC03/SC05 | **`loopscale-oracle-spot-price`** (family) | fake token sets the price, drains both |
| 24 | PuzzleWallet | SC01 | **`proxy-storage-collision`** | proxy/wallet slot overlap + multicall |
| 25 | Motorbike | SC01 | **`unprotected-privileged-fn`** | unprotected `initialize` → `selfdestruct` |
| 26 | DoubleEntryPoint | SC02 | *defensive level* | register a Forta detection bot |
| 27 | GoodSamaritan | SC02 | *gap: custom-error control flow* | revert `NotEnoughBalance()` to trigger sweep |
| 28 | GatekeeperThree | SC01 | *gap: multi-gate* | `construct0r` + password + reverting owner |
| 29 | Switch | — | *gap: calldata manipulation* | offset the `_data` pointer past the guard |
| 30 | HigherOrder | SC05 | *gap: raw calldata* | store a word > 255 via `calldataload` |
| 31 | Stake | SC02 | *gap: phantom accounting* | "stake" a fake WETH that never transfers |

**Bold** = solved by an exact catalog detector. *gap* = solved with a general technique that points at
a detector class the catalog doesn't yet encode.

## The catalog detectors that earned their keep

Ten levels are caught by an exact catalog entry — the same detectors that fire on mainnet hacks:

- **`insecure-randomness`** (CoinFlip) — block-variable RNG is precomputable.
- **`proxy-storage-collision`** (Delegation, Preservation, PuzzleWallet) — the most-reused detector;
  the real-world twin is the Audius **$1.08M** [fork replay](fork-simulation).
- **`cei-reentrancy`** (Reentrance) — interaction-before-effect; The DAO class.
- **`unprotected-privileged-fn`** (Fallout, Motorbike, Fallback) — a privileged path with no guard;
  real-world twin is the DAO Maker **$5.76M** [fork replay](fork-simulation).
- **`loopscale-oracle-spot-price`** (Dex, DexTwo) — pricing off a manipulable spot ratio; real-world
  twins are Mango **$114M** and Loopscale.

> Worked example (Delegation → `proxy-storage-collision`). Code signal: `fallback()` does
> `delegate.delegatecall(msg.data)`, and `Delegate.owner` / `Delegation.owner` both occupy slot 0.
> `applies_when` holds: *"a proxy that delegatecalls into an implementation"*, *"an implementation
> state variable shares a storage slot with a proxy bookkeeping pointer"*, *"a logic function reachable
> through the proxy writes that slot"*. PROVE: call with `pwn()`'s selector → owner overwritten.

## The newer levels (32–40)

Upstream Ethernaut added 9 levels past the classic 31. Catalog sweep + status:

| Level | Class | Catalog detector | Status |
|---|---|---|---|
| **Impersonator** | SC01 | **`signature-replay-malleability`** | ✅ solved — raw `ecrecover` (no low-s check); the malleable twin `(v^1, r, N−s)` recovers the same controller and hashes to an unused key → `changeController(…, address(0))` |
| **Forger** | SC01 | **`signature-replay-malleability`** | ✅ solved — replay-guard keys on `keccak256(signature)`, but OZ `ECDSA.recover` accepts the EIP-2098 64-byte compact form of the same sig → mint 100+100 = 200 |
| **BetHouse** | SC08 | **`cei-reentrancy`** | ✅ solved — `Pool.withdrawAll` refunds ETH (`.call`) before burning wrapped; re-deposit in the callback to transiently reach the 20-token bet threshold, then `makeBet(player)` |
| **ImpersonatorTwo** | SC01 | **`ecdsa-nonce-reuse-key-extraction`** | ✅ solved — two factory sigs share the same `r` ⇒ **ECDSA nonce reuse leaks the owner key** (`k = (h1−h2)·inv(s1−s2)`, `d = (s1·k−h1)·inv(r)`); forge owner sigs → `setAdmin(player)` → `switchLock` → `withdraw`. Surfaced the *new* `ecdsa-nonce-reuse-key-extraction` detector |
| **EllipticToken** | SC01 | `signature-replay-malleability` | ⏳ deferred — voucher/permit hash-domain confusion; the obvious `permit` route is blocked by `usedHashes[bytes32(amount)]`, needs a deeper insight |
| **MagicAnimalCarousel** | SC07 | *gap* (bit-packing) | ✅ solved — `setAnimalAndSpin` XOR-writes the animal, so a pre-filled crate corrupts it. `changeAnimal` only ORs the nextId (no backward pointer), so route a spin through crate 65534 whose nextId wraps (`% MAX_CAPACITY`) to 0, pre-fill the unguarded crate 0, and let the Goat spin land there. **Catalog gap → bit-encoding detector candidate** |
| **UniqueNFT** | SC08 | `cei-reentrancy` (+ **EIP-7702**) | ✅ solved — `checkOnERC721Received` fires before `_mint` (CEI violation); `mintNFTEOA` is not `nonReentrant` and only checks `tx.origin==msg.sender`. Give the player EOA code (EIP-7702 delegation; modeled with `vm.etch` under the paris-pinned suite) so its receiver hook re-enters while balance is still 0 → 2 mints |
| **Cashback** | — | *gap* (**EIP-7702**) | ⏳ deferred — win requires the player EOA's code to equal the 7702 designator `0xef0100‖instance`; brand-new account-abstraction class |
| **NotOptimisticPortal** | SC02 | `verus-bridge-merkle-forgery` (fam) | ⏳ deferred — Optimism portal message-verification; needs the OP stack vendored |

**6 / 9 solved in-harness; all 9 evaluated.** The catalog validations (Impersonator, Forger
→ `signature-replay-malleability`; BetHouse, UniqueNFT → `cei-reentrancy`), ImpersonatorTwo (→ the new
`ecdsa-nonce-reuse-key-extraction` detector), and MagicAnimalCarousel (bit-packing) are added to
`ethernaut/test/`. The 3 deferred: **infra-heavy** (Cashback needs EIP-7702 + ERC-1155 + transient
storage; NotOptimisticPortal needs the Optimism stack) and a **deeper puzzle** (EllipticToken's
domain confusion).

## Gaps the wargame surfaced (the to-do list)

The levels solved with general techniques are exactly the detector classes the catalog should grow
into. Three more were just promoted to detectors this round:

- ✅ **Denial-of-service** — King, Denial (reverting recipient / gas-griefing) → now
  [`dos-griefing-revert`](pocs#dos-griefing-revert).
- ✅ **Forced ether** — Force/King (`selfdestruct` balance assumptions) → now
  [`forced-ether-balance-assumption`](pocs#forced-ether-balance-assumption).
- ✅ **Calldata / ABI manipulation** — Switch, HigherOrder → now
  [`calldata-abi-smuggling`](pocs#calldata-abi-smuggling).
- **Information exposure** — Vault, Privacy (`private` ≠ secret). *(to-do)*
- **Integer / storage underflow** — Token, AlienCodex (a pre-0.8 / `unchecked` class; the catalog's
  only overflow entry is the Move `cetus-amm-overflow`). *(to-do)*
- **`tx.origin` authentication** — Telephone, Gatekeepers. *(to-do)*
- **Untrusted-interface assumptions** — Elevator, Shop. *(to-do)*

> This is the loop working as intended — the Reentrance level prompted [`cei-reentrancy`](pocs#cei-reentrancy),
> and Force/King/Denial/Switch just produced three more detectors. The remaining classes are tracked
> follow-ups.

## Reproduce

```bash
cd ethernaut
forge test -vv        # 31 levels, all passing
```

Level sources under `ethernaut/src/levels/` are vendored verbatim from
`github.com/OpenZeppelin/ethernaut` (MIT); `ethernaut/src/vendor/` holds minimal OZ shims so they
compile standalone. Older-pragma levels (^0.5/^0.6/<0.7) are deployed via `deployCode`.
