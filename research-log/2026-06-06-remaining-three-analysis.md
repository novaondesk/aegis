# 2026-06-06 — Analysis of the final 3 Ethernaut levels (not yet solved)

Honest status: after solving ImpersonatorTwo, MagicAnimalCarousel, and UniqueNFT (→ 37/40), the
last three are infra-/insight-heavy multi-session items. Documenting the analysis so the next pass
starts ahead rather than re-deriving. No partial/broken code was committed for these.

## EllipticToken — blocked on a crypto insight (no infra needed)
Win: `balanceOf(ALICE) == 0` (factory mints ALICE 10 ETK). The only lever to move ALICE's tokens is
`permit`, which `_approve(tokenOwner, spender, amount)` with `tokenOwner = ECDSA.recover(bytes32(amount),
sig)`. To approve *from ALICE* you must recover ALICE — and ECDSA recovery yields a *specific* address
only for a message that address actually signed. The only ALICE signature in existence is `aliceSignature`
over `VH = keccak256(abi.encodePacked(10e18, ALICE, salt))` (from `createInstance`'s `redeemVoucher`).
That forces `bytes32(amount) == VH` ⇒ `amount = uint256(VH)`, but `redeemVoucher` already set
`usedHashes[VH] = true`, so `require(!usedHashes[bytes32(amount)])` reverts.
- Ruled out: recovering ALICE over a *different* message (needs ALICE's key or a discrete-log break);
  EIP-2098 short-sig (the repo's `ECDSA` supports it, but it only bypasses *signature*-keyed replay
  guards like Forger — `usedHashes` here is **hash**-keyed, so 2098 changes nothing); the malleable
  high-s twin (the shim rejects high-s).
- Open question for next pass: is there a second 32-byte message ALICE effectively "signed" (e.g. via
  the spender-accept hash path, or some `abi.encode` vs `encodePacked` domain overlap) whose
  `usedHashes` slot is NOT set? No public writeup exists yet (level is brand-new).

## Cashback — needs a Prague EVM profile + heavy infra
Win (`validateInstance`): player must accrue `NATIVE_MAX_CASHBACK` + `FREE_MAX_CASHBACK` ERC-1155
balances, own ≥2 `SuperCashbackNFT` (incl. `ownerOf(uint160(player)) == player`), AND
`player.code.length == 23 && bytes23(player.code) == 0xef0100‖instance` — i.e. the player EOA must be
**functionally** EIP-7702-delegated to the instance (calls route through `onlyDelegatedToCashback`,
which reads `msg.sender.code[0x17:]`, plus a transient `unlock`).
- `vm.etch` (the trick used for UniqueNFT) only sets code *bytes* — under the suite's `paris` EVM the
  `0xef0100…` designator is NOT executed as a delegation (invalid opcode `0xef`). This level needs a
  real `evm_version = prague` profile + `vm.signAndAttachDelegation`.
- Infra to vendor (OZ v5.4): `ERC1155`, `TransientSlot`, `IERC20`/`IERC721`, plus the factory's
  `ERC20`/`ERC721`/`Ownable`. Also uses Solidity 0.8.30 `contract … layout at <slot>` (explicit storage
  layout) — confirm the installed solc supports it.
- Plan: add `[profile.prague]` (evm_version=prague) so the default paris suite (old SELFDESTRUCT
  levels) is untouched; document `FOUNDRY_PROFILE=prague forge test --match-contract Cashback`.

## NotOptimisticPortal — needs OP-stack libs + a proof bug
Win: `totalSupply() > 0` (any mint). `executeMessage` mints only after `_verifyMessageInclusion`
(Merkle-Patricia proof against an `l2StateRoots` entry seeded from the genesis RLP header). Forging a
valid MPT proof against the fixed genesis stateRoot is infeasible by brute force, so the intended path
is a verification bug (note: `_executeOperation` runs attacker-controlled receivers/data **before**
proof verification; and `sendMessage`/storage-slot bookkeeping looks abusable). Requires vendoring
`Lib_RLPReader` + `Lib_SecureMerkleTrie` (~9.5KB, `eth-optimism/contracts@0.6.0`). Lowest priority.

## Recommendation
Cashback is the most "finishable" of the three once a `prague` profile + ERC-1155/TransientSlot shims
exist. EllipticToken needs the crypto insight (or a writeup). NotOptimisticPortal is the heaviest.
