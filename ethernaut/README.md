# ethernaut/ — Aegis vs. the Ethernaut wargame

Aegis solves OpenZeppelin's [Ethernaut](https://ethernaut.openzeppelin.com/) CTF using only its own
[catalog](../catalog/exploits.yaml) + [`aegis-audit`](../skills/aegis-audit/SKILL.md) loop: RECON the
level → SWEEP it against the catalog → PROVE by exploiting the real level contract and asserting the
level's win condition. Each level is deployed and exploited locally in Foundry.

**Full write-up (which catalog detector caught each level + the matched `applies_when`):**
[`docs/ethernaut-wargame.md`](../docs/ethernaut-wargame.md).

## Run
```bash
cd ethernaut
forge test -vv     # forge-std reused from ../poc/lib; level sources vendored under src/levels/
```

## Solved (5/5)
| Level | Class | Catalog detector | Test |
|---|---|---|---|
| #3 CoinFlip | SC09 | `insecure-randomness` | `test/CoinFlip.t.sol` |
| #6 Delegation | SC01 | `proxy-storage-collision` | `test/Delegation.t.sol` |
| #10 Reentrance | SC08 | `cei-reentrancy` | `test/Reentrance.t.sol` |
| #22 Dex | SC03 | `loopscale-oracle-spot-price` (price-manip family) | `test/Dex.t.sol` |
| #25 Motorbike | SC01 | `unprotected-privileged-fn` | `test/Motorbike.t.sol` |

Level sources under `src/levels/` are vendored verbatim from `github.com/OpenZeppelin/ethernaut`
(MIT); `src/vendor/` holds minimal OZ shims so they compile standalone.
