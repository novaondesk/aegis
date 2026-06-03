# Research Log — 2026-06-03 — Ekubo Callback Calldata Injection

## Done
- Deep-dived Ekubo Protocol $1.4M exploit (May 5 2026, Ethereum + Arbitrum)
- Root cause: Ekubo's `pay()` function forwards arbitrary trailing calldata to the caller's callback and verifies only that Core's own token balance increased. A malicious callback contract extracted a victim address and amount from the forwarded calldata, then called `transferFrom(victim, Core, amount)` using the victim's pre-existing unlimited WBTC approval.
- Key insight: Ekubo Core's balance was zero — the protocol was a drain rail, not the loss source. DARKNAVY classifies this as a "standing approval drain routed through Ekubo" rather than an Ekubo insolvency event.
- The verified Ekubo code functions correctly per its design. The systemic risk is in the callback pattern: any contract that forwards arbitrary calldata to a callback and checks only its own balance creates a drain rail for users with standing approvals.
- This is the same calldata-injection class as the SwapNet $17M exploit (Jan 2026) — the common pattern is "forward attacker-controlled data to an external call where it can encode a victim address and amount for transferFrom."
- Created case study: `docs/exploits/ekubo-callback-approval-drain-2026-05-05.md`
- Added catalog entry: `ekubo-callback-approval-drain` in `catalog/exploits.yaml`
- Added 3 checklist items: `SC02-CB-1`, `SC02-CB-2`, `SC02-CB-3` in `checklists/master-checklist.md`
- Added semgrep rule: `calldata-forwarding-in-payment` in `tools/semgrep/solidity-patterns.yml`
- Updated `docs/exploits/2026-recent-exploits.md` with corrected root cause

## Takeaways
- The distinction between "protocol vulnerability" and "approval drain via protocol rail" matters for bounty classification. Ekubo Core had no bug — the attack vector was the combination of (1) calldata forwarding, (2) balance-only verification, and (3) standing approvals.
- Standing unlimited approvals are the real villain. The victim approved the malicious contract 158 days before the exploit. `revoke.cash` is not optional.
- Flash-accounting patterns (lock → withdraw → pay → callback) create a natural drain rail when the callback can source repayment from arbitrary addresses. Any protocol with this pattern should validate the funding source, not just the balance delta.
- Ekubo's contracts are immutable — no patch possible, only redeployment. This is a design-level issue, not a code-level fix.
- This is the 14th case study in the aegis catalog, covering a new vulnerability class (callback calldata injection / SC02-CB).

## Next
- [ ] Kelp DAO bridge exploit deep-dive ($292M, April 2026) — research complete, needs case study write-up
- [ ] Yearn yETH share-calc deep-dive (last remaining backlog item from web3isgoinggreat)
- [ ] Create Foundry PoC for callback calldata injection pattern (Ekubo-style)
- [ ] Target scouting: active bug bounty programs on Immunefi/HackenProof
