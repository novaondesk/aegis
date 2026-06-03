# Release-gate checklist — evidence-backed deploy/upgrade readiness

Blue-team gate for *your own* deployments. **Evidence first:** every result cites a file
(contract, deploy script, CI workflow, config, test). Separate **Detection** (what the repo
proves) from **Policy** (what should be enforced but isn't).

## A. Build integrity
- [ ] Compiler version pinned (`foundry.toml` / `hardhat.config`), not a floating pragma range.
- [ ] Dependencies pinned + lockfile committed (`foundry.lock`, submodule commits, package lock).
- [ ] Build reproducible (`forge build` clean; no uncommitted artifacts driving deploy).
- [ ] No `console`/debug, test-only backdoors, or `vm.*` cheatcodes in production paths.

## B. Upgrade safety (if upgradeable)
- [ ] **Storage layout compatible** — new vars appended only; no reorder/resize/remove of
  existing slots (diff the layout, e.g. `forge inspect <C> storage-layout`).
- [ ] Initializers protected — `initializer`/`reinitializer`, `_disableInitializers()` in the
  implementation constructor; implementation can't be initialized standalone.
- [ ] No `selfdestruct`, no `delegatecall` to a mutable/attacker-influenceable target.
- [ ] Upgrade authority is a timelock + multisig, not an EOA.
- [ ] Function-selector / proxy-collision checked (Transparent/UUPS/Beacon/Diamond as applicable).

## C. Access control & ownership handoff
- [ ] Privileged functions enumerated; each has the intended role guard (cross-check with
  aegis-audit's semantic-guard engine).
- [ ] Two-step ownership transfer (`transferOwnership` + `acceptOwnership`); no one-step to a
  raw address.
- [ ] No leftover deployer powers after setup; roles renounced/transferred as intended.
- [ ] Timelock on asset-affecting privileged actions; users can exit before they take effect.

## D. Signer / multisig opsec
- [ ] Multisig threshold and signer set documented and match on-chain.
- [ ] Threshold appropriate (not 1-of-N for a treasury); signer key custody evidenced.
- [ ] Emergency/guardian role scoped (pause only, not drain).

## E. Config drift
- [ ] Deploy params (token addresses, oracle feeds, caps, fees) match an address book /
  intended config — no hardcoded testnet/placeholder values.
- [ ] Oracle feeds point at the right asset + heartbeat; caps/weights set as designed.
- [ ] Per-network configs separated; no mainnet deploy reading a test config.

## F. Monitoring & safety rails
- [ ] Pausability present and tested; pause reachable by the guardian.
- [ ] Circuit breakers / caps for the catalog classes the protocol touches (oracle deviation,
  per-asset borrow caps, withdraw rate limits).
- [ ] Events emitted on privileged actions for off-chain monitoring.
- [ ] Invariant tests (`tools/foundry-invariants/`) exist for the protocol's core invariants.

## CI / supply chain (if CI deploys)
- [ ] Actions pinned to commit SHAs (not floating tags); least-privilege tokens.
- [ ] Deploy secrets scoped; no plaintext keys in workflow/env; no `pull_request_target` misuse.

## Report template
```markdown
# Aegis release-gate — <repo> @ <commit>

## Classification
Framework: …  Language: …  Upgradeability: …  Protocol: …  Deploy: …  CI: …

## Gate results
| Check | Detection (evidence) | Verdict |
|-------|----------------------|---------|
| Build integrity | foundry.toml pins 0.8.24; lockfile present | PASS |
| Upgrade safety  | UUPS; storage layout diff clean; initializer disabled | PASS |
| Access control  | owner is EOA (deploy/Deploy.s.sol:L20) | CONDITION: move to timelock+multisig |
| Signer opsec    | no multisig evidence in repo | CONDITION: document threshold/signers |
| Config drift    | oracle = mainnet ETH/USD feed | PASS |
| Monitoring      | no pause function | CONDITION: add pausability |

## Remediation (from MITIGATE mode)
| # | Finding | Fix | Proven by | Residual risk |
|---|---------|-----|-----------|---------------|
| F-1 | … | … | Safe<X> ✓ | none |

## Release verdict
BLOCK | PASS-WITH-CONDITIONS | PASS
- <each condition, with the evidence line it came from>
```
