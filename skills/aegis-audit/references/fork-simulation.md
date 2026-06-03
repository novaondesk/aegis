# Fork-simulation (the PROVE phase for real, deployed targets)

`poc/` holds minimal, chain-agnostic **models** of catalog patterns — great for teaching a
detector and proving a fix in the abstract. But when you audit an *actual deployed target*, prove
the finding against **forked real state**: the target contract, its tokens, oracles, AMM pools, and
even other users' standing approvals are all live on the fork at their real addresses. You deploy
only your **attacker contract**. This is the DeFiHackLabs methodology and it makes oracle/AMM/
economic exploits testable for real (real liquidity, real prices), not hand-waved.

Harness lives in [`../../sim/`](../../sim/).

## The loop (RECON → SWEEP unchanged; PROVE becomes a fork)
1. **Pin a block.** `vm.createSelectFork(vm.rpcUrl("mainnet"), BLOCK)`. For a historical incident,
   pin the block just before the attack tx (needs an **archive** RPC). For a current audit, pin a
   recent block.
2. **Source the target.** Verified source from Etherscan; unverified → decompile with `heimdall-rs`.
   Map the target + its dependency addresses.
3. **Run the catalog sweep** against the source (Phase 2) → ranked hypotheses.
4. **Exploit on the fork.** Deploy your attacker; use cheatcodes to set up:
   - `vm.prank` / `vm.startPrank` — act as any address (incl. privileged roles).
   - `deal(token, who, amt)` — fund the attacker with real tokens.
   - You do **not** redeploy the target or its deps — they already exist on the fork.
5. **Confirm.** The finding is real when the catalog entry's stated `invariant` breaks **and** the
   attacker ends with profit (assert balance deltas). Record the pinned block.

## Confirmed → `fork_poc`
A passing fork replay is what lets a catalog entry carry a *real* `fork_poc` (vs. a model PoC).
Worked example: [`sim/test/SocketApprovalDrain_2024_01.t.sol`](../../sim/test/SocketApprovalDrain_2024_01.t.sol)
forks Ethereum at block 19,021,453 and drains a real victim's ~656k USDC through the real Socket
Gateway's malicious route — the ground-truth instance of `approval-drain-arbitrary-call`.

## Setup
`sim/` needs an RPC endpoint in the environment (archive, to pin historical blocks):
```bash
cd sim && cp .env.example .env   # fill ETH_RPC_URL with an archive endpoint
set -a; source .env; set +a
forge test --match-contract <Replay> -vvv
```

## Scope / ethics
Forking is local — no real funds move, nothing is broadcast — so it's a safe way to test even
before disclosure. Still: only simulate against **in-scope bounty targets, your own deploys, or
public post-mortems**. Never broadcast an exploit tx to a live network.

## Limits
- EVM only via this `forge` flow. Solana needs `solana-test-validator --clone` / surfpool; Sui/Move
  need Move-native fork tooling — separate harnesses.
- Unverified targets → heimdall pseudo-source is lossy.
- This proves *catalog patterns + constructible exploits*. It is not an autopilot 0-day finder —
  the sweep focuses where to look; a human/agent still crafts the exploit transaction.
