# ethernaut/ — Aegis vs. the Ethernaut wargame

Aegis solves **36 of the 40 levels** of OpenZeppelin's [Ethernaut](https://ethernaut.openzeppelin.com/)
CTF using only its [catalog](../catalog/exploits.yaml) + [`aegis-audit`](../skills/aegis-audit/SKILL.md)
loop: RECON the level → SWEEP the catalog → PROVE by exploiting the real level contract and asserting
the level's win condition. Each level is deployed and exploited locally in Foundry.

> Upstream Ethernaut grew past the classic 31 — there are now **40 playable levels**. All 9 newer ones
> are evaluated (catalog sweep) in [the report](../docs/ethernaut-wargame.md#the-newer-levels-3240);
> 5 are solved in-harness here (Impersonator, ImpersonatorTwo, Forger, BetHouse, MagicAnimalCarousel).

**Full write-up** (which detector caught each level + the catalog gaps it surfaced):
[`docs/ethernaut-wargame.md`](../docs/ethernaut-wargame.md).

## Run
```bash
cd ethernaut
forge test -vv     # 36 levels, all passing
```

## Coverage
**36 / 40** levels (`test/<Level>.t.sol`). Fourteen are caught by an exact catalog detector — the same
ones that fire on mainnet hacks:

| Catalog detector | Levels |
|---|---|
| `proxy-storage-collision` | Delegation, Preservation, PuzzleWallet |
| `unprotected-privileged-fn` | Fallout, Motorbike, Fallback |
| `loopscale-oracle-spot-price` (price-manip) | Dex, DexTwo |
| `insecure-randomness` | CoinFlip |
| `cei-reentrancy` | Reentrance, **BetHouse** |
| `signature-replay-malleability` | **Impersonator**, **Forger** |
| `ecdsa-nonce-reuse-key-extraction` | **ImpersonatorTwo** |

The rest are solved with general techniques (forced-ether, DoS, info-exposure, integer/storage
underflow, tx.origin, calldata, untrusted-interface, bit-encoding/packing) — an honest to-do list of
detector classes the catalog should grow into. The **4 deferred** newer levels (UniqueNFT, Cashback →
EIP-7702; NotOptimisticPortal → Optimism stack; EllipticToken → deeper puzzle) are evaluated +
sketched in the report.

Level sources under `src/levels/` are vendored verbatim from `github.com/OpenZeppelin/ethernaut`
(MIT); `src/vendor/` + `src/helpers/` hold minimal OZ shims so they compile standalone (the newer
levels added `ECDSA` + `ReentrancyGuard` shims). Older-pragma levels (^0.5 / ^0.6 / <0.7) are deployed
via `deployCode`.
