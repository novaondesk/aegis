# CONTINUE.md — handoff for the next contributor

You're picking up **Aegis** (exploit-catalog-driven smart-contract auditing). Read
[`AGENTS.md`](AGENTS.md) first — it's the contract for how to contribute (the loop, the four
places every studied exploit must update, the hard rules). This file is the *current state +
the next moves*, last updated 2026-06-06.

## Ground rules you must follow
- **Push guardrail:** a pre-commit hook confines plain commits to `intake/` + `research-log/`. To
  commit reviewed/proven work to canonical dirs (`catalog/`, `poc/`, `docs/`, `ethernaut/`, `dvd/`),
  prefix the commit with `AEGIS_PROMOTE=1` and push with `AEGIS_PUSH=1`:
  ```bash
  AEGIS_PROMOTE=1 git commit -m "..."
  AEGIS_PUSH=1 git push origin main
  ```
- **No claimed finding without a runnable PoC.** A solve isn't done until `forge test` is green.
- **Push after every commit** (the human collaborates via the remote).
- Small, focused commits; explain *why* in the body.

### Build / verify / commit / push — exact mechanics (read this, it's not obvious)
- **forge**: `/Users/wren/.foundry/bin/forge` (v1.7.x). `poc/` builds natively. For an ethernaut level,
  verify in isolation (skips the x86-only old levels — see build note):
  ```bash
  cd ethernaut && forge test --match-contract <X>Test -vv \
    --skip 'src/vendor/oz06/*' Token Fallout HigherOrder Reentrance Motorbike AlienCodex Ownable-05
  ```
- **Commit identity** (per AGENTS.md — do NOT add a Claude/AI co-author trailer):
  ```bash
  AEGIS_PROMOTE=1 git -c user.name=novaondesk -c user.email=novaondesk@users.noreply.github.com commit -m "..."
  ```
  (No git hooks are actually installed in this clone, but keep `AEGIS_PROMOTE=1` for faithfulness.)
- **Push** — `origin` is HTTPS to `github.com/novaoc/aegis`; auth uses the token in
  `/Users/wren/nova/.nova_secrets` as `GITHUB_TOKEN_NOVAOC`:
  ```bash
  TOKEN=$(grep -E "^GITHUB_TOKEN_NOVAOC=" /Users/wren/nova/.nova_secrets | cut -d= -f2-)
  AEGIS_PUSH=1 git push "https://x-access-token:${TOKEN}@github.com/novaoc/aegis.git" main
  ```
- A new level = vendor source verbatim from `OpenZeppelin/ethernaut` (`curl` the raw
  `contracts/src/levels/<Name>.sol` + factory), add any missing shim under `src/vendor/oz/`, write the
  test mirroring the factory's `createInstance`/`validateInstance`, then update README + the
  `docs/ethernaut-wargame.md` count/row, append a `research-log/` entry, commit+push.

## Where things are
| Path | What |
|---|---|
| `catalog/exploits.yaml` | The 35 detectors (single source of truth). Schema + how-to in `catalog/README.md`. |
| `poc/` | Foundry project: one `Vulnerable<X>`+`Safe<X>`+test per detector. `cd poc && forge test` = **66 green** (native, no Rosetta). |
| `ethernaut/` | Wargame harness. **37/40 solved**; full `cd ethernaut && forge test` needs Rosetta (see build note) — until then verify per-level in isolation. |
| `dvd/` | Damn Vulnerable DeFi v4 solutions — **18/18**. |
| `docs/` | The just-the-docs site (`the-catalog.md`, `pocs.md`, `ethernaut-wargame.md`, `dvd-wargame.md`, `exploits/<id>.md`). |
| `intake/backlog.md` | The research backlog (9 P1/P2 seed rows still `todo`). |
| `research-log/` | **Append a dated entry every session.** |

Current totals: **catalog 35 detectors** · **poc 66 tests** · **Ethernaut 37/40** · **DVD 18/18**.

> **Build note (Apple Silicon):** the older levels pin x86-only `solc` 0.5.x/0.6.x, so the *full*
> `cd ethernaut && forge test` needs **Rosetta 2** (`sudo softwareupdate --install-rosetta`). Without
> it, verify a single modern level in isolation with
> `forge test --match-contract <X> --skip 'src/vendor/oz06/*' Token Fallout HigherOrder Reentrance Motorbike AlienCodex Ownable-05`.
> The `poc/` suite is all `^0.8.20` and builds natively. **Do NOT delete the old levels to dodge this.**

## Done since last handoff (2026-06-06)
- **ImpersonatorTwo** ✅ solved (k-reuse) — the prior commit's test never passed (assumed nonce 2
  without the factory init; encoded `v` as 32 bytes). Rewritten + verified in isolation; counts 34→35.
- New catalog detector **`ecdsa-nonce-reuse-key-extraction`** (full four-places unit; on-chain key
  recovery via the modexp precompile; `poc` 64→66). catalog 34→35 detectors.
- **MagicAnimalCarousel** ✅ solved (35→36) — XOR-write corruption via the `% MAX_CAPACITY` wrap to
  `nextId==0` (revisit unguarded crate 0). See `research-log/2026-06-06-magic-animal-carousel.md`.
- **UniqueNFT** ✅ solved (36→37) — CEI reentrancy; the player EOA gains code (EIP-7702, modeled with
  `vm.etch` since the suite is paris-pinned) so its `onERC721Received` re-enters `mintNFTEOA`. Added
  minimal OZ-v5 ERC721 shims under `src/vendor/oz/`. See `research-log/2026-06-06-uniquenft-7702-reentrancy.md`.

## The immediate job: the 3 remaining deferred Ethernaut levels

Ethernaut grew to **40 playable levels**; we solve 37. The 3 open ones are fully evaluated +
exploit-sketched in [`docs/ethernaut-wargame.md` § The newer levels](docs/ethernaut-wargame.md), with a
deeper per-level analysis (why each is still open + the concrete next step) in
[`research-log/2026-06-06-remaining-three-analysis.md`](research-log/2026-06-06-remaining-three-analysis.md)
— **read that first.** Sources are in the OZ repo (`OpenZeppelin/ethernaut`,
`contracts/src/levels/<Name>.sol` + `<Name>Factory.sol` — the factory's `validateInstance` is the win
condition you must satisfy).

To add a level: vendor `src/levels/<Name>.sol` into `ethernaut/src/levels/`, point its imports at the
existing shims (`openzeppelin-contracts-08/` → `src/vendor/oz/`; `-v4.6.0/` and `-v5.4.0/` are remapped
there too), add any missing shim under `src/vendor/oz/`, then write `test/<Name>.t.sol` that deploys
the level (mirroring the factory's `createInstance`) and asserts `validateInstance`'s condition. Shims
already present: `Ownable`, `ERC20` (+`_mint`/`_burn`/`transferOwnership`), `ECDSA` (65 + EIP-2098 64-byte
+ low-s reject), `ReentrancyGuard` (both `security/` and `utils/`), `Proxy`, `Address`, and (added for
UniqueNFT) minimal OZ-v5 **ERC721** (`token/ERC721/ERC721.sol` + `IERC721Receiver.sol` +
`utils/ERC721Utils.sol`). Still missing for Cashback: `ERC1155`, `TransientSlot`, `IERC20`/`IERC721`.

Ordered by value/tractability:

1. **EllipticToken** — voucher/permit hash-domain confusion. Win: `balanceOf(ALICE) == 0` (factory mints
   ALICE 10 ETK). **Analysis so far (next contributor, start here):** the only lever to move ALICE's
   tokens is `permit`, which `_approve`s `tokenOwner→spender` with `tokenOwner = ECDSA.recover(bytes32(amount),
   sig)` and `spender` signing `keccak256(abi.encodePacked(tokenOwner, spender, amount))` (you control
   spender = your key). To approve *from ALICE* you must recover ALICE — and the only ALICE signature in
   existence is `aliceSignature` over the voucher hash `VH = keccak256(abi.encodePacked(10e18, ALICE, salt))`
   (from `createInstance`). That forces `bytes32(amount) == VH` ⇒ `amount = uint256(VH)`, but
   `redeemVoucher` already set `usedHashes[VH] = true`, so `require(!usedHashes[bytes32(amount)])` reverts.
   The unsolved crux: find a way to recover ALICE over a NON-used 32-byte message. Re-examine OZ-v4 `ECDSA`'s
   EIP-2098 short-sig path + zero-address/`ecrecover(0,…)` quirks, and whether `permit`'s
   `usedHashes[permitHash]` vs `usedHashes[bytes32(amount)]` (only `permitHash` is nullified on use) leaves a
   gap. Win then: `permit` ALICE→you for a huge amount, `transferFrom(ALICE, you, 10e18)`.
2. **Cashback** — EIP-7702: win requires the player EOA's code to equal the 7702 delegation designator
   `0xef0100‖instance` and to accrue cashback via the delegated flow. Brand-new account-abstraction class —
   **candidate new detector** (7702 delegation abuse). Heaviest (ERC-1155 + transient storage + the
   `onlyDelegatedToCashback` code-introspection modifier). NOTE: the suite is **paris**-pinned; the
   `vm.etch`-models-7702 trick used for UniqueNFT may not suffice here because the win literally checks the
   EOA's code *equals the 7702 designator bytes* — this likely needs a `prague` test profile (or a `vm.etch`
   of the exact `0xef0100‖instance` designator bytes). Vendor an OZ-v5 ERC-1155 shim.
3. **NotOptimisticPortal** — Optimism portal message-verification (~9.5KB, needs the OP stack
   vendored). Maps to the `verus-bridge-merkle-forgery` family. Lowest priority (infra-heavy).

When you finish a level: update `ethernaut/README.md` + `docs/ethernaut-wargame.md` counts/table,
append `research-log/`, commit (promote) + push.

## After that — the roadmap (do these in order, once the 6 levels above are done)

### Phase 2 — new wargame: Paradigm CTF
Same loop as Ethernaut/DVD: clone the public foundry ports (`paradigm-ctf-2021`, `-2022`, `-2023` —
verify the exact challenge list against the repos), RECON each challenge → SWEEP the catalog → PROVE
by exploiting it and asserting the challenge's win hook. Put solutions in a new `paradigm/` harness
mirroring `ethernaut/` (vendored challenge source + minimal shims + `test/<Name>.t.sol`), and write
`docs/paradigm-wargame.md`. **Only the smart-contract challenges are in scope** — skip the crypto /
reversing / pwn / EVM-bytecode-puzzle tracks (SourceCode/quine, JOP, Electric Sheep, Trapdoor, etc.).

Aegis-relevant challenges (sweep result — confirm against the real source before coding):

| Challenge (year) | Bug | Catalog detector |
|---|---|---|
| **Sentiment** (2022) | Balancer pool read-only reentrancy | `read-only-reentrancy` ✅ |
| **Merkledrop** (2022) | merkle multiproof / duplicate-leaf forgery | `verus-bridge-merkle-forgery` fam ✅ |
| **Broker** (2021) | Uniswap V2 spot-price manipulation → bad borrow | `mango-oracle-manipulation` / `loopscale-oracle-spot-price` ✅ |
| **Bank / TokenBank** (2021) | ERC-223 `tokenFallback` reentrancy | `cei-reentrancy` ✅ |
| **Upgrade / UpgradeV2** (2021) | uninitialized UUPS proxy seized | `unprotected-privileged-fn` / `proxy-storage-collision` ✅ |
| **RPGItem / Dropper / Dai** (2022/23) | EIP-712 / permit signature abuse | `signature-replay-malleability` ✅ |
| **Rescue** (2022) | MasterChef accidental-token accounting | `incorrect-reward-accounting` ✅ |
| **Grains of Sand** (2023) | stablecoin swap rounding / dust extraction | `weird-erc20-accounting` / precision ✅ |
| **Vanity** (2022) | `ecrecover` → `address(0)` accepted (auth bypass) | **gap** → new signature-validation detector |
| **Vault** (2021) | reading "private" storage slots | **gap** → info-exposure detector |
| **Lockbox / Lockbox2** (2021/22) | calldata/ABI crafting | ties into `calldata-abi-smuggling` |

~8–10 map straight onto existing detectors (strong validation); ~3 surface new gaps. Heavier
fork/infra setup than DVD — budget for plumbing. Update `README` + the docs site count when done.

### Phase 3 — burn down the catalog backlog
`intake/backlog.md` has **9 `todo` seed rows**: euler-donation-liquidation, curve-vyper-reentrancy,
kyberswap-tick, wormhole-sigverif, nomad-init, cream/rari/penpie reentrancy, platypus-logic. Each
becomes a full catalog unit (case study + entry + `Vulnerable`/`Safe`/test + checklist + semgrep);
flip the row `todo → promoted`.

Also **promote the 3 `studied` entries to `coded`** (they already have case studies + catalog
entries + checklist items from Nova's PR #10 — they just need runnable PoCs):
- **`yearn-yeth-solver-underflow`** (SC02/SC07, $9M) — model a weighted-stableswap solver where
  Newton-Raphson divergence drives the product term Π→0 and `unsafe_sub(A·Σ, D·Π)` underflows to mint
  ~2.35×10⁵⁶ LP from a dust deposit; `Safe<X>` checks the solver domain + uses checked arithmetic.
- **`transit-finance-legacy-approval-drain`** (SC02) — a "deprecated" (frontend-removed but still
  callable) router that forwards arbitrary calldata while holding standing approvals → drain; `Safe<X>`
  is paused/approval-revoked. (Close cousin of `approval-drain-arbitrary-call`.)
- **`hyperbridge-mmr-leaf-index`** (SC02) — an MMR proof verifier missing a leaf-index bounds check
  (unconsumed leaves silently skipped) + no proof↔message binding → forge a cross-chain state proof;
  `Safe<X>` bounds-checks + binds the proof. (Cousin of `verus-bridge-merkle-forgery`.)
Add each PoC under `poc/test/`, flip the catalog `status: studied → coded` + set `poc`/`poc_cmd`, and
add the block to `docs/pocs.md` (and bump the "29 coded" count in README / `the-catalog.md`).

### Phase 4 — close the remaining gap classes as detectors
Not yet catalog detectors: information-exposure (`private` ≠ secret), integer/storage underflow,
`tx.origin` auth (has a semgrep rule, no entry), untrusted-interface assumptions, a generic
precision-asymmetry detector (DVD Shards), and the EIP-7702 delegation-abuse class (from UniqueNFT /
Cashback above). Several of these are *also* surfaced by Paradigm (Vanity, Vault) — fold them in.

### Phase 5 — make the `fork_poc` links real
The catalog's `fork_poc:` references to DeFiHackLabs are mostly documentation; only 4 real mainnet-fork
replays exist in `sim/`. Add `sim/` replays for the highest-loss mined classes so the cross-links are
actually run, not just cited.

> Always append a dated `research-log/` entry per session, and keep `README` + the docs site
> (`the-catalog.md`, `pocs.md`) counts in sync with `catalog/exploits.yaml`.

## How your work will be reviewed
Open a small, focused commit per level/detector (or a PR). The reviewer checks: (1) `cd ethernaut &&
forge test` and `cd poc && forge test` are green; (2) the win condition asserted matches the factory's
`validateInstance`; (3) any new catalog entry parses
(`python3 -c "import yaml; yaml.safe_load(open('catalog/exploits.yaml'))"`) and follows the schema with
checkable `applies_when` + a `root_cause` + `variant_queries`; (4) the four-places loop is complete
(case study + catalog + checklist + detection artifact); (5) committed + pushed cleanly. Keep the
exploit faithful to the real level (don't weaken `setUp`/`validateInstance`).
