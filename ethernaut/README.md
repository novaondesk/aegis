# ethernaut/ — Aegis vs. the Ethernaut wargame

Aegis solves **all 40 levels** of OpenZeppelin's [Ethernaut](https://ethernaut.openzeppelin.com/)
CTF using only its [catalog](../catalog/exploits.yaml) + [`aegis-audit`](../skills/aegis-audit/SKILL.md)
loop: RECON the level → SWEEP the catalog → PROVE by exploiting the real level contract and asserting
the level's win condition. Each level is deployed and exploited locally in Foundry.

> Upstream Ethernaut grew past the classic 31 — there are now **40 playable levels**, all solved
> in-harness here. The newer ones are also evaluated against the catalog in
> [the report](../docs/ethernaut-wargame.md#the-newer-levels-3240).

**Full write-up** (which detector caught each level + the catalog gaps it surfaced):
[`docs/ethernaut-wargame.md`](../docs/ethernaut-wargame.md).

## Run
```bash
cd ethernaut
forge test -vv                                              # 39 levels (paris profile)
FOUNDRY_PROFILE=prague forge test --match-contract Cashback # Cashback (EIP-7702, Cancun/Prague)
```
The split is only about EVM version: Cashback needs Cancun/Prague (transient storage, EIP-7702)
while the classic SELFDESTRUCT levels need paris. Each profile's `skip` list excludes the other's
incompatible-pragma sources. Both are run in CI.

## Coverage
**40 / 40** levels (`test/<Level>.t.sol`). Fifteen are caught by an exact catalog detector — the same
ones that fire on mainnet hacks:

| Catalog detector | Levels |
|---|---|
| `proxy-storage-collision` | Delegation, Preservation, PuzzleWallet |
| `unprotected-privileged-fn` | Fallout, Motorbike, Fallback |
| `loopscale-oracle-spot-price` (price-manip) | Dex, DexTwo |
| `insecure-randomness` | CoinFlip |
| `cei-reentrancy` | Reentrance, **BetHouse**, **UniqueNFT** (EIP-7702) |
| `signature-replay-malleability` | **Impersonator**, **Forger** |
| `ecdsa-nonce-reuse-key-extraction` | **ImpersonatorTwo** |

The rest are solved with general techniques (forced-ether, DoS, info-exposure, integer/storage
underflow, tx.origin, calldata, untrusted-interface, bit-encoding/packing) — an honest to-do list of
detector classes the catalog should grow into. The hardest newer levels (Cashback → EIP-7702;
NotOptimisticPortal → Optimism selector-collision + forged L2 proof; EllipticToken → raw-ECDSA
forgery) are now solved in-harness; the catalog gaps each surfaced are tracked in the report.

Level sources under `src/levels/` are vendored verbatim from `github.com/OpenZeppelin/ethernaut`
(MIT); `src/vendor/` + `src/helpers/` hold minimal OZ shims so they compile standalone (the newer
levels added `ECDSA` + `ReentrancyGuard` shims). Older-pragma levels (^0.5 / ^0.6 / <0.7) are deployed
via `deployCode`.
