# 2026-06-01 — First EVM deep-dive + agent contribution setup

## What we did
- Decision: **go deep on EVM first** (per user). Stood up a real Foundry project at
  `poc/` (forge 1.7.1).
- Built the flagship deep-dive: **ERC-4626 first-depositor / share-inflation attack**.
  - `poc/src/VulnerableVault.sol` (balanceOf accounting + no offset + round-down).
  - `poc/src/SafeVault.sol` (OZ-style virtual offset).
  - `poc/test/InflationAttack.t.sol` — **both tests pass**: vulnerable vault is drained
    (attacker +0.5e18, victim redeemable 1.5e18 of 2e18 deposited); safe vault makes the
    attack unprofitable (attacker −0.5e18, victim keeps ~1.9998e18).
  - `docs/exploits/erc4626-inflation-attack.md` written from the template.
- Authored **`AGENTS.md`** — the contribution contract for Nova/other agents (mission,
  hard rules, repo map, the loop, conventions, definition of done).
- Authored **`docs/research-plans/nova-solana-base-dayplan.md`** — a full-day, time-boxed
  plan: morning Solana/Anchor (checklist + 1 PoC + targets), afternoon Base/OP-Stack
  (L2 addendum checklist + live target triage).
- `poc/README.md`, README status bump to v0.2.

## Gotcha logged
`vm.prank(x); c.f(c.g())` — inner `c.g()` consumes the prank; `c.f` then runs as the
test contract. Read values into locals before pranking. (Cost us the safe-vault test.)

## Open item for the user
- GitHub remote: `gh` is authed as **`0xAjax-ai`**, but memory says repos live under
  **`novaondesk`**. Need the user to confirm **owner + visibility (private recommended)**
  before `gh repo create` + push.

## Next
- [ ] Push to remote once owner/visibility confirmed.
- [ ] Nova executes the Solana + Base day-plan.
- [ ] Turn VaultShareInvariant template into a runnable stateful invariant in `poc/`.
- [ ] Deep-dives with real source: Cetus, Balancer V2, Yearn yETH.
