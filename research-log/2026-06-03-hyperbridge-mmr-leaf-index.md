# Research Log: Hyperbridge MMR Verifier Exploit — 2026-06-03

## What I looked at
- web3isgoinggreat.com feed — identified new code exploits since last run (June 3)
- Filtered out social engineering/key compromise: Drift ($285M, admin key takeover via durable nonces — NK social engineering), Wasabi Protocol ($5M, compromised admin key), Bitcoin Depot ($3.67M)
- Identified Hyperbridge MMR verifier exploit as the strongest new code exploit case study

## What I found
### Hyperbridge MMR Verifier — $237K extracted, 1B DOT minted (April 13, 2026)

**Root cause:** `VerifyProof()` in solidity-merkle-trees iterated over MMR peaks and assigned leaves to each peak's range, but never checked whether any leaves were left unconsumed. An attacker submitted one legitimate leaf and one forged leaf with an out-of-bounds index. The verifier reconstructed the genuine root from the first leaf (the second was silently skipped) and returned success.

**Three independent failures compounded:**
1. MMR bounds check missing (out-of-bounds leaf silently skipped)
2. No proof-to-message binding in `handlePostRequests()` (proof for one message validated a different message)
3. `challengePeriod` was set to zero (built-in dispute window disabled)

Any one of these being absent would have stopped the exploit. All three were open.

**Key insight:** The same structural bug appeared independently in three separate production Merkle verifier libraries (solidity-merkle-trees, paritytech/merkle-mountain-range, antouhou/rs-merkle), each written by different teams. This is a genuinely undertested property across the ecosystem — not a mistake unique to any one codebase.

**Additional findings from SRLabs + internal audit:**
- Duplicate leaf index attack (MerkleMountainRange + MerkleMultiProof): attacker with one valid key could submit same vote multiple times, each counting toward supermajority
- Empty proof acceptance: verifier exits early with `break` instead of rejecting when proof data runs out
- Single-leaf fast path accepts trailing data
- IntentGatewayV2: partial fills over-release escrow, fee-on-transfer over-credits, stuck ETH, governance can permanently disable gateway

**Dollar figure understates severity:** $237K extracted, but the vulnerability granted unlimited minting authority over all gateway-managed tokens. Same bug on deeper-liquidity token = catastrophic.

## Done
- [x] Case study written: `docs/exploits/hyperbridge-mmr-leaf-index-2026-04-13.md`
- [x] Catalog entry added (30th entry): `hyperbridge-mmr-leaf-index`
- [x] Master checklist items added: SC02-MMR-BOUNDS, SC02-PROOF-BIND, SC02-CHALLENGE-PERIOD
- [x] Base-l2-addendum item added: MMR Verifier Correctness section
- [x] Research log written

## Takeaways
1. **Iterator exhaustion checks are a blind spot.** The MMR verifier was cryptographically sound in its hash computations — the bug was a missing *bookkeeping* check (are all leaves consumed?). This class of vulnerability — iterator exhaustion, bounds validation, canonicality requirements — is undertested across the entire bridge ecosystem.
2. **Challenge periods are security-critical.** A zero challenge period means forged state commitments execute instantly. Governance must not be able to set it to zero.
3. **Proof-to-message binding is essential.** Without it, a proof for one message can validate a different (forged) message.
4. **Fuzzing beats static analysis for verifier bugs.** Polytope Labs now publishes continuous structural fuzzing harnesses — these would have caught all variants.

## Next
- [ ] Create Foundry PoC for MMR out-of-bounds leaf pattern (demonstrate the verification bypass)
- [ ] Add semgrep rule `mmr-unconsumed-leaves` for detecting missing post-loop checks
- [ ] Research Volo Protocol Sui vault exploit ($3.5M, April 2026) — code exploit on Sui/Move, would stand up Sui research track
- [ ] Research TAC bridge exploit ($2.8M, May 2026) — bridge exploit, need more technical details
