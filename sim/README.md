# sim/ — Fork-simulation harness

Forks a real chain at a pinned block and exploits the **real deployed target** + its live
dependencies. Where [`../poc/`](../poc/) holds minimal *models* of catalog patterns, `sim/` proves
findings against **real on-chain state** — the target, tokens, oracles, pools, and even other
users' standing approvals already exist on the fork. You deploy only your attacker contract.

This is the `aegis-audit` **PROVE phase for deployed targets** — see
[`../skills/aegis-audit/references/fork-simulation.md`](../skills/aegis-audit/references/fork-simulation.md).

## Setup
```bash
cd sim
cp .env.example .env          # fill ETH_RPC_URL with an ARCHIVE endpoint (to pin historical blocks)
set -a; source .env; set +a   # load the RPC url into the env forge reads
forge test -vvv               # forge-std is reused from ../poc/lib (see foundry.toml libs)
```
`.env` is gitignored — never commit the key.

## Tests
| Test | What it proves |
|------|----------------|
| `test/ForkSanity.t.sol` | Harness shake-out: forks Ethereum at a pinned block, reads real USDC state, funds an attacker via `deal`. If this passes, forking works. |
| `test/SocketApprovalDrain_2024_01.t.sol` | **Real incident replay** — Socket Gateway approval drain (2024-01, ~$3.3M). Forks at block 19,021,453 and drains a real victim's ~656k USDC through the real gateway's malicious route. Ground-truth instance of catalog `approval-drain-arbitrary-call`. |
| `test/AudiusGovTakeover_2022_07.t.sol` | **Real incident replay** — Audius governance takeover (2022-07, ~$1.08M). Forks at block 15,201,793; the storage-collision re-initializer lets the attacker seize the real Governance/Staking/DelegateManager proxies and pass a proposal transferring 99% (~18.56M) of the AUDIO treasury. Ground-truth instance of catalog `proxy-storage-collision`. |

## Writing a new replay / target audit
1. Pin the block: historical incident → the block *before* the attack tx; live audit → a recent block.
2. Declare the real target + dependency addresses (verified source, or heimdall for unverified).
3. Deploy only your attacker; use `vm.prank` (act as any address) and `deal` (fund with real tokens).
4. Assert the catalog entry's `invariant` breaks **and** the attacker profits (balance deltas).
5. A passing replay is the catalog entry's real `fork_poc`.

## Scope
Local only — nothing is broadcast. Simulate against in-scope bounty targets, your own deploys, or
public post-mortems. Never send an exploit tx to a live network.
