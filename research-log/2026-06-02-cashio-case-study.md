# Research Log — 2026-06-02: Cashio Infinite Mint Case Study

## What I did
- Wrote a deep-dive case study for the Cashio App exploit (March 2022, ~$52.8M drained on Solana)
- Source: Cashio's `brrr` program had missing collateral validation — attacker created fake bank → fake Saber swap → fake LP tokens, minted 2B real CASH, swapped for real assets
- Added 2 new checklist items to `checklists/solana-anchor-checklist.md`:
  - **Trusted Root / Anchor-of-Trust Validation** — when validating account chains, verify the root is program-controlled
  - **Permissionless Initialization Risk** — if accounts are user-creatable, downstream validation must verify authorization
- Added trusted-root pattern to `checklists/master-checklist.md` under SC02 Business Logic

## Key takeaways
1. **"Passes all checks" ≠ "is legitimate"** — Cashio had 6 `assert_keys_eq!` calls that all passed. The bug was in what was NOT checked.
2. **Solana-specific attack surface** — EVM has `msg.sender` and contract-level access control. Solana's account model requires each instruction to independently validate its account chain. Missing one link = entire chain fakeable.
3. **Permissionless init is a red flag** — If users can create banks/pools/collateral accounts, the validation must anchor to a program-controlled whitelist.
4. **Detection heuristic** — For each `assert_keys_eq!` chain: "Can an attacker create a fake version of the first account that satisfies all downstream checks?"

## Primary sources
- CertiK: https://www.certik.com/blog/cashio-app-incident-analysis
- Halborn: https://www.halborn.com/blog/post/explained-the-cashio-hack-march-2022
- Ackee Blockchain: https://ackee.xyz/blog/2022-solana-hacks-explained-cashio/
- PoC workshop: https://github.com/NaryaAI/cashio-exploit-workshop

## Next steps
- [ ] Anchor PoC for CPI target spoofing (Loopscale pattern) — from vault TODO
- [ ] Write detection script that scans Anchor programs for unanchored account chains
- [ ] Balancer V2 ComposableStablePool rounding deep-dive
- [ ] Target scouting: 3-5 active Solana Immunefi programs
