# 2026-06-06 — Solve Ethernaut UniqueNFT (CEI reentrancy via EIP-7702-delegated EOA)

## Scope
Deferred level (per CONTINUE.md). Needed an OZ 5.x ERC721 shim under `ethernaut/src/vendor/oz/`.

## The bug
`_mintNFT` does `require(balanceOf(msg.sender)==0)` → `tokenId++` → `checkOnERC721Received(0,0,msg.sender,…)`
→ `_mint(...)`. The receiver hook fires **before** the balance update (CEI violation), and
`mintNFTEOA` has **no** `nonReentrant` guard — only `tx.origin == msg.sender`. So if `msg.sender`
(the player) has code, its `onERC721Received` can re-enter `mintNFTEOA` while `balanceOf` is still 0,
minting a second NFT. Win: `balanceOf(player) > 1`.

## EIP-7702 + the paris constraint
The level's intended trick is **EIP-7702**: delegate the player EOA to attacker code so the EOA both
passes `tx.origin == msg.sender` (it IS the caller) and has code for the hook to fire. Foundry's 7702
cheatcodes need `evm_version = prague`, but this suite is pinned to **paris** (older levels rely on
pre-EIP-6780 SELFDESTRUCT — Force/King), and switching globally would break them.

**Resolution:** model the *outcome* of the delegation — "the EOA now has code" — with `vm.etch(player,
attackerCode)`, which is exactly the precondition the exploit needs. `tx.origin == msg.sender` still
holds (player is the pranked caller + originator). The attacker keeps `nft` as an `immutable` (lives in
code, survives the etch) and a one-shot `reentered` storage flag. This stays on paris and faithfully
reproduces the vulnerability + win condition. (If a `prague` profile is added later, swap to
`vm.signAndAttachDelegation` for a literal 7702 repro.)

## Done
- Vendored `ethernaut/src/levels/UniqueNFT.sol` verbatim (`0.8.30`).
- Added minimal OZ-v5 shims used by the level: `token/ERC721/ERC721.sol` (name/symbol/balanceOf/
  ownerOf/virtual `_update`/`_mint`), `token/ERC721/IERC721Receiver.sol`,
  `token/ERC721/utils/ERC721Utils.sol` (the `onERC721Received` acceptance check — the reentrancy
  surface), and `utils/ReentrancyGuard.sol` (v5 moved it from `security/`).
- `ethernaut/test/UniqueNFT.t.sol`: etch-modeled 7702 delegate re-enters once → `balanceOf(player)==2`.
  `forge test --match-contract UniqueNFTTest` (isolation) → **PASS** (gas 257,627). Maps to `cei-reentrancy`.
- Counts 36 → **37 / 40**; README + wargame row flipped to ✅.

## Next
EllipticToken (permit/voucher domain confusion — deeper insight), Cashback (7702 + ERC-1155 +
transient storage), NotOptimisticPortal (OP stack). Full ethernaut aggregate still pending Rosetta 2.
