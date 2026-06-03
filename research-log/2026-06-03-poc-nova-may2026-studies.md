# Research Log — 2026-06-03 — PoCs for Nova's May-2026 studies (PR #9 follow-through)

## Context
Merged Nova's PR #9 (5 new `studied` case studies: Ekubo, TrustedVolumes, Verus, Kelp DAO,
THORChain) to main, then completed the contribution loop by porting the PoC-able ones to runnable
Foundry PoCs (`studied → coded`). Full `poc/` suite: **50 passed / 0 failed** (24 suites).

## Done — 3 new coded PoCs
- **trustedvolumes-access-control** (SC01, `TrustedVolumesAccess.t.sol`): RFQ proxy with a `public`
  `setAuthorizedSigner` and no modifier — attacker authorizes their own key, signs an order for the
  whole inventory, drains it. Safe = `onlyOwner` on the setter (legit owner-authorized signer still
  fills). Mirrors the $6.7M incident.
- **verus-bridge-merkle-forgery** (SC02, `VerusMerkleForgery.t.sol`): bridge verifies a withdrawal's
  Merkle proof against a **caller-supplied root that's never authenticated** → attacker builds a
  1-leaf tree with their own withdrawal (`root = leaf`, empty proof) and drains. Safe = only accept
  roots committed by the authenticated relayer (+ a spent-leaf nullifier). Faithful to the doc's
  "verification did not properly constrain the root"; same family as Nomad 2022.
- **kelp-dao-layerzero-dvn-1-1** (X01, `KelpDvnThreshold.t.sol`): a 1-of-1 verifier threshold lets a
  single compromised/forged attestation authorize a release. Safe = require ≥2 distinct, independent
  verifiers (strictly-increasing signer addresses → no dup). Modeled the on-chain enforcement point
  (attestation quorum), which generalizes to multisig bridges / oracle quorums.

## Deliberately left `studied` (skip-reason recorded in the catalog entry)
- **ekubo-callback-approval-drain**: Ekubo Core is correct-by-design; the loss requires a victim to
  have approved the *attacker's own* callback contract (outside the protocol), so no "safe Ekubo"
  vulnerable/safe pair can defeat it. The reusable signal stays in `applies_when`/`root_cause`.
- **thorchain-tss-gg20-key-extraction**: off-chain GG20/Paillier threshold-signature flaw in Go
  `tss-lib` — no Solidity invariant to break. A native MPC repro would be the fidelity follow-up.

## Notes
- Catalog now **26 entries: 24 coded, 2 studied**. Updated `poc/README` PoC table.
- The `studied → coded` flip is exactly how the v1.0 catalog matured (Nova writes the case study;
  the PoC port follows). Both skip decisions are honest per AGENTS rule #5 (mark skip + reason)
  rather than shipping synthetic PoCs.

## Next
- Backlog still has the P1/P2 seed candidates (Euler, Curve-Vyper, KyberSwap, Wormhole, Nomad,
  Rari/Fei, Penpie, Platypus) as `todo`.
