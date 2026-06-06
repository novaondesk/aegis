# 2026-06-06 — New catalog detector: ecdsa-nonce-reuse-key-extraction

## Scope
CONTINUE.md level #1 (ImpersonatorTwo) called for promoting the k-reuse insight into a full catalog
detector. Built the complete four-places unit.

## Done
- **PoC** ([`poc/src/signature/NonceReuse.sol`](../poc/src/signature/NonceReuse.sol),
  [`poc/test/NonceReuse.t.sol`](../poc/test/NonceReuse.t.sol)): a `SignerGatedVault` (replay- and
  malleability-safe OZ-style gate) plus an `EcdsaNonceReuse` library that recovers a private key
  **on-chain** from two same-`r` signatures using the modexp precompile (`0x05`) for modular inverse.
  - `test_vulnerable_kReuseExtractsKeyAndDrains`: recovers the key from a fixed-`k` vector set, forges
    a valid `release` sig, drains the vault → invariant broken.
  - `test_safe_uniqueNonceCannotExtractKey`: with unique nonces (distinct `r`) the same math yields
    garbage, not the key.
  - Vectors generated offline with a pure-Python fixed-`k` secp256k1 signer; recovery (`k`,`d`)
    independently verified in Python before porting. `cd poc && forge test --match-contract NonceReuse`
    → 2/2 PASS; full `poc` suite **66/66**.
- **Catalog** entry `ecdsa-nonce-reuse-key-extraction` (SC01, status coded) with checkable
  `applies_when` (multi-use signer key; two observable sigs; shared `r`; no proven RFC-6979/CSPRNG) and
  a one-line `root_cause`. Catalog parses → 35 entries (30 coded, 5 studied).
- **Case study** `docs/exploits/ecdsa-nonce-reuse-key-extraction.md`; **checklist** item
  `SC01-NONCE-REUSE`; **semgrep** heuristic `ecdsa-signer-weak-nonce` (predictable on-chain nonce).
- Synced counts: README + `docs/the-catalog.md` (34→35 detectors), `docs/pocs.md` block added.

## Key point
This is deliberately distinct from `signature-replay-malleability`: **no verifier-side check prevents
it** (nonce binding, EIP-712 domain, low-s are all irrelevant). The defect is signer-side nonce
generation; detection = mining the signer's historical signatures for a repeated `r`.

## Next
Continue the deferred Ethernaut levels: MagicAnimalCarousel (self-contained bit-packing),
EllipticToken (permit/voucher domain confusion), then the EIP-7702 pair (UniqueNFT, Cashback),
then NotOptimisticPortal. (Full ethernaut aggregate run still pending a Rosetta-equipped host.)
