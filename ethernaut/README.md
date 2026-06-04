# ethernaut/ — Aegis vs. the Ethernaut wargame

Aegis solves **all 31 levels** of OpenZeppelin's [Ethernaut](https://ethernaut.openzeppelin.com/) CTF
using only its [catalog](../catalog/exploits.yaml) + [`aegis-audit`](../skills/aegis-audit/SKILL.md)
loop: RECON the level → SWEEP the catalog → PROVE by exploiting the real level contract and asserting
the level's win condition. Each level is deployed and exploited locally in Foundry.

**Full write-up** (which detector caught each level + the catalog gaps it surfaced):
[`docs/ethernaut-wargame.md`](../docs/ethernaut-wargame.md).

## Run
```bash
cd ethernaut
forge test -vv     # 31 levels, all passing
```

## Coverage
**31 / 31** levels (`test/<Level>.t.sol`). Ten are caught by an exact catalog detector — the same
ones that fire on mainnet hacks:

| Catalog detector | Levels |
|---|---|
| `proxy-storage-collision` | Delegation, Preservation, PuzzleWallet |
| `unprotected-privileged-fn` | Fallout, Motorbike, Fallback |
| `loopscale-oracle-spot-price` (price-manip) | Dex, DexTwo |
| `insecure-randomness` | CoinFlip |
| `cei-reentrancy` | Reentrance |

The other 21 are solved with general techniques (forced-ether, DoS, info-exposure, integer/storage
underflow, tx.origin, calldata, untrusted-interface) — an honest to-do list of detector classes the
catalog should grow into. See the report.

Level sources under `src/levels/` are vendored verbatim from `github.com/OpenZeppelin/ethernaut`
(MIT); `src/vendor/` + `src/helpers/` hold minimal OZ shims so they compile standalone. Older-pragma
levels (^0.5 / ^0.6 / <0.7) are deployed via `deployCode`.
