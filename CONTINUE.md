# CONTINUE.md — handoff for the next contributor

You're picking up **Aegis** (exploit-catalog-driven smart-contract auditing). Read
[`AGENTS.md`](AGENTS.md) first — it's the contract for how to contribute (the loop, the four
places every studied exploit must update, the hard rules). This file is the *current state +
the next moves*, written 2026-06-04.

## Ground rules you must follow
- **Push guardrail:** a pre-commit hook confines plain commits to `intake/` + `research-log/`. To
  commit reviewed/proven work to canonical dirs (`catalog/`, `poc/`, `docs/`, `ethernaut/`, `dvd/`),
  prefix the commit with `AEGIS_PROMOTE=1` and push with `AEGIS_PUSH=1`:
  ```bash
  AEGIS_PROMOTE=1 git commit -m "..."
  AEGIS_PUSH=1 git push origin main
  ```
- Use the project's existing commit identity; don't add an AI co-author trailer.
- **No claimed finding without a runnable PoC.** A solve isn't done until `forge test` is green.
- **Push after every commit** (the human collaborates via the remote).
- Small, focused commits; explain *why* in the body.

## Where things are
| Path | What |
|---|---|
| `catalog/exploits.yaml` | The 31 detectors (single source of truth). Schema + how-to in `catalog/README.md`. |
| `poc/` | Foundry project: one `Vulnerable<X>`+`Safe<X>`+test per detector. `cd poc && forge test` = 64 green. |
| `ethernaut/` | Wargame harness. `cd ethernaut && forge test` = **34/34 green** (34 of 40 levels). |
| `dvd/` | Damn Vulnerable DeFi v4 solutions — **18/18**. |
| `docs/` | The just-the-docs site (`the-catalog.md`, `pocs.md`, `ethernaut-wargame.md`, `dvd-wargame.md`, `exploits/<id>.md`). |
| `intake/backlog.md` | The research backlog (9 P1/P2 seed rows still `todo`). |
| `research-log/` | **Append a dated entry every session.** |

Current totals: **catalog 31 detectors** · **poc 64 tests** · **Ethernaut 34/40** · **DVD 18/18**.

## The immediate job: the 6 deferred Ethernaut levels

Ethernaut grew to **40 playable levels**; we solve 34. The 6 open ones are fully evaluated +
exploit-sketched in [`docs/ethernaut-wargame.md` § The newer levels](docs/ethernaut-wargame.md).
Sources are in the OZ repo (`OpenZeppelin/ethernaut`, `contracts/src/levels/<Name>.sol` +
`<Name>Factory.sol` — the factory's `validateInstance` is the win condition you must satisfy).

To add a level: vendor `src/levels/<Name>.sol` into `ethernaut/src/levels/`, point its imports at the
existing shims (`openzeppelin-contracts-08/` → `src/vendor/oz/`; `-v4.6.0/` and `-v5.4.0/` are remapped
there too), add any missing shim under `src/vendor/oz/`, then write `test/<Name>.t.sol` that deploys
the level (mirroring the factory's `createInstance`) and asserts `validateInstance`'s condition. Shims
already present: `Ownable`, `ERC20` (+`_mint`/`_burn`/`transferOwnership`), `ECDSA` (65 + EIP-2098 64-byte
+ low-s reject), `ReentrancyGuard`, `Proxy`, `Address`.

Ordered by value/tractability:

1. **ImpersonatorTwo** — *highest value.* The factory's two signatures share the same `r`, which
   means **ECDSA nonce (k) reuse → the owner's private key is recoverable**:
   `k = (h1−h2)·inv(s1−s2) mod n`, `d = (s1·k − h1)·inv(r) mod n` (do `inv` via the modexp precompile
   `0x05` with Fermat: `a^(n−2) mod n`). `h1`,`h2` are the two `toEthSignedMessageHash` messages the
   owner signed (`"lock0"` and `"admin1"‖ADMIN` — mind the `Strings.toString(nonce)` + `abi.encodePacked`
   ordering). Recover `d` in the test, then `vm.sign(d, ...)` to forge owner sigs → `setAdmin(player)`
   → `switchLock` (unlock) → `withdraw`. Win: `instance.balance == 0`.
   **This should also become a NEW catalog detector** `ecdsa-nonce-reuse-key-extraction` (full Aegis
   unit per AGENTS.md: case study + catalog entry + `Vulnerable`/`Safe`/test + checklist + semgrep).
2. **UniqueNFT** — `checkOnERC721Received` fires *before* `_mint`/balance update → reentrancy, but the
   player EOA must have code for the hook to fire. Use **EIP-7702**: `vm.signAndAttachDelegation` to
   delegate the player EOA to an attacker contract whose `onERC721Received` re-enters `mintNFTEOA`
   (passes `tx.origin == msg.sender` because the EOA *is* the caller) while balance is still 0 → 2 NFTs.
   Needs an OZ 5.x ERC721 shim (`_update` override + `ERC721Utils.checkOnERC721Received`). Win:
   `balanceOf(player) > 1`. Maps to `cei-reentrancy` (+ a 7702 angle worth a detector note).
3. **Cashback** — EIP-7702 again: win requires the player EOA's code to equal the 7702 delegation
   designator `0xef0100‖instance` and to accrue cashback via the delegated flow. Brand-new
   account-abstraction class — **candidate new detector** (7702 delegation abuse). Heaviest (ERC-1155
   + transient storage + the `onlyDelegatedToCashback` code-introspection modifier).
4. **EllipticToken** — voucher/permit hash-domain confusion. The obvious `permit` drain of ALICE is
   blocked by `usedHashes[bytes32(amount)]` (the voucher hash is already marked). Needs a deeper
   insight (re-examine how `redeemVoucher` vs `permit` share `usedHashes` and whether a malleable/2098
   variant of ALICE's voucher signature opens a different `amount`). Win: `balanceOf(ALICE) == 0`.
5. **MagicAnimalCarousel** — pure bit-packing puzzle. `ANIMAL_MASK`/`NEXT_ID_MASK` overlap (note
   `<<160+16` precedence) and `setAnimalAndSpin` writes the animal with `^` (XOR), so a crate that
   already holds animal bits gets *corrupted* rather than overwritten. Arrange (via `changeAnimal`,
   whose `encodedAnimal<<160` bleeds into the nextId field) for the validator's `"Goat"` spin to land
   on a pre-filled crate. Win: stored animal != Goat encoding. No external deps. This is a **catalog
   gap** (arithmetic/bit-encoding).
6. **NotOptimisticPortal** — Optimism portal message-verification (~9.5KB, needs the OP stack
   vendored). Maps to the `verus-bridge-merkle-forgery` family. Lowest priority (infra-heavy).

When you finish a level: update `ethernaut/README.md` + `docs/ethernaut-wargame.md` counts/table,
append `research-log/`, commit (promote) + push.

## Other open work (lower priority)
- **Backlog** (`intake/backlog.md`, 9 `todo` seed rows): euler-donation-liquidation, curve-vyper-reentrancy,
  kyberswap-tick, wormhole-sigverif, nomad-init, cream/rari/penpie reentrancy, platypus-logic. Each
  becomes a full catalog unit; flip the row `todo → promoted` when done.
- **Remaining classic-Ethernaut gap classes** not yet catalog detectors: information-exposure
  (`private` ≠ secret), integer/storage underflow, `tx.origin` auth (has a semgrep rule, no entry),
  untrusted-interface assumptions, a generic precision-asymmetry detector (DVD Shards).

## How your work will be reviewed
Open a small, focused commit per level/detector (or a PR). The reviewer checks: (1) `cd ethernaut &&
forge test` and `cd poc && forge test` are green; (2) the win condition asserted matches the factory's
`validateInstance`; (3) any new catalog entry parses
(`python3 -c "import yaml; yaml.safe_load(open('catalog/exploits.yaml'))"`) and follows the schema with
checkable `applies_when` + a `root_cause` + `variant_queries`; (4) the four-places loop is complete
(case study + catalog + checklist + detection artifact); (5) committed + pushed cleanly. Keep the
exploit faithful to the real level (don't weaken `setUp`/`validateInstance`).
