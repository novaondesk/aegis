# Research Log — 2026-06-03 — Fork-simulation harness + first real incident replay

## Goal
Move from minimal *model* PoCs to **fork simulation**: fork a real chain at a pinned block and
exploit the real deployed target + its live dependencies. Validate the pipeline on a historical hack
before pointing it at a live target (user decision).

## Done
- **New `sim/` Foundry harness** (separate from `poc/` models). `foundry.toml` reuses `../poc/lib`
  forge-std and wires `[rpc_endpoints].mainnet = "${ETH_RPC_URL}"`. RPC = the ab-snipe Alchemy
  Ethereum endpoint (chainId 1, **archive** confirmed — reads state back to ≥block 14M). Key lives
  in a **gitignored** `sim/.env` (never committed); `.env.example` documents setup.
- **Harness shake-out** (`test/ForkSanity.t.sol`): forks ETH at block 21,000,000, reads real USDC
  totalSupply (~$25.8B), funds an attacker via `deal`. Confirms forking + real-state reads + cheats.
- **First real incident replay** (`test/SocketApprovalDrain_2024_01.t.sol`): forks ETH at block
  **19,021,453** and reproduces the Socket Gateway approval drain (2024-01-16). One call to the REAL
  gateway's malicious route 406 (`performAction` forwards attacker `swapExtraData`) drains a REAL
  victim's **656,424.98 USDC** via their standing approval — victim → 0, attacker → +$656k. Only the
  attacker (the test contract) is deployed; gateway/USDC/approval are real on-chain state.
  - Ground-truth instance of catalog `approval-drain-arbitrary-call`; its `fork_poc` now points here.
  - Public facts (addresses/block/route id) cross-referenced from post-mortems + the local
    DeFiHackLabs index; exploit calldata reconstructed from the route ABI, not copied.

## Wired
- `aegis-audit` SKILL Phase 5 gained a **Fork-PROVE mode** note + new reference
  `references/fork-simulation.md` (the loop, cheatcodes, scope/ethics, limits).
- `sim/README.md` documents setup + the two tests + how to add a replay.

## Notes / limits
- EVM-only via this `forge` flow; Solana/Sui need separate harnesses (later, per user).
- A snag worth remembering: the Socket route calls back into the receiver after the action, so the
  attacker contract needs a payable `receive()`/`fallback()` or the whole tx reverts.
- This proves catalog patterns + constructible exploits against real state — not an autopilot
  0-day finder. The sweep still focuses where to look; the exploit tx is crafted.

## Next
- Point fork-sim at a live in-scope target (or own deploy): RECON → catalog SWEEP → fork-PROVE.
- More historical replays to harden the harness (Seneca, Audius, Beanstalk are in the DHL index).
- Solana fork harness (`solana-test-validator --clone` / surfpool) when we tackle non-EVM targets.
