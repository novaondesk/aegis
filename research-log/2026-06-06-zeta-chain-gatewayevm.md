# Research Log: 2026-06-06 — ZetaChain GatewayEVM Three-Defect Exploit

## Scope
ZetaChain GatewayEVM exploit (April 29, 2026) — $333K drained from internal team wallets across Ethereum, Arbitrum, Base, BSC.

## Sources
- Cryptotimes post-mortem: https://www.cryptotimes.io/2026/04/29/how-a-perfect-storm-of-3-bugs-led-to-zetachains-333k-gatewayevm-exploit/
- SlowMist analysis
- ZetaChain official communications

## Findings

### Three Independent Defects (All Must Hold for Exploit)

1. **GatewayZEVM.call() on ZetaChain — Unauthenticated Entry Point**
   - No access control, no input validation on `call(destinationContract, message, isArbitraryCall)`
   - Only cosmetic checks: minimum gas limit, max message size
   - Any address can emit `Called` event with arbitrary payload

2. **GatewayEVM.execute() on Destination Chains — Arbitrary Calldata Execution**
   - Accepts arbitrary `target.call(data)` including `token.transferFrom(victim, attacker, amount)`
   - Gateway IS the caller, so standing ERC20 approvals to gateway are used
   - No allow-list of valid targets; token contracts not rejected

3. **Standing Approvals — Trust Assumption**
   - Users (including internal team wallets) granted unlimited ERC20 approvals to gateway via `deposit()`
   - Approvals never revoked; no revocation guidance provided
   - Approvals persisted for months/years

### Attack Flow
1. Attacker funds wallet via Tornado Cash (3 days prep)
2. Deploys exploit contract on ZetaChain
3. Calls `GatewayZEVM.call()` with `destinationContract`=GatewayEVM (Ethereum), `message`=`transferFrom(victim, attacker, amount)`, `isArbitraryCall`=true
4. TSS validators sign the `Called` event (treat all events as legitimate)
5. GatewayEVM on Ethereum receives signed message, executes `target.call(data)` where target=victim's token (USDC/USDT)
6. Gateway's standing approval is used (msg.sender=GatewayEVM, approved by victim)
7. Repeated across 9 transactions, 3 victim wallets, 4 chains
8. Stolen USDC/USDT converted to ETH and consolidated

## Deliverables Created

1. **PoC** (`poc/src/zeta/GatewayEVM.sol` + `poc/test/ZetaGatewayEVM.t.sol`)
   - VulnerableGatewayEVM: models all three defects
   - SafeGatewayEVM: fixes all three (allow-listed callers, allow-listed targets, no standing approvals)
   - 5 tests pass: vulnerable exploit + 3 safe guards + MockERC20 validation

2. **Case Study** (`docs/exploits/zeta-chain-gatewayevm-2026-04-29.md`)
   - Full technical breakdown with code excerpts
   - Attack walkthrough with quantified gains
   - Detection guidance (semgrep rules, checklist items)

3. **Catalog Entry** (`catalog/exploits.yaml`)
   - ID: `zeta-chain-gatewayevm`
   - Status: `coded` (runnable PoC)
   - Class: SC02, SC05, SC01
   - Checklist: [SC02, SC05, SC01]
   - Semgrep tags: [unauthenticated-cross-chain-call, arbitrary-execute-target, standing-approval-risk]

## Key Insights

- **Composition bug**: Each contract individually appears correct. The vulnerability emerges from the composition of three defects across two chains (ZetaChain + EVM chains).
- **Static analysis gap**: Slither cannot detect this — no single contract has a flaw. Requires manual checklist review of: (1) unauthenticated gateway entry, (2) arbitrary execute target, (3) standing approval risk.
- **Reusable pattern**: This is a "confused deputy" class where a gateway contract holding user approvals becomes a weapon. Same class as:
  - ApprovalDrain (Socket/Seneca/Sushi)
  - Ekubo callback approval drain
  - Transit Finance legacy contract
- **Fixes are straightforward but require all three**:
  1. Authenticate cross-chain message senders (TSS validator allow-list)
  2. Validate execute targets against allow-list; reject token contracts
  3. Eliminate standing approvals (use exact-amount approve+transfer+revoke, or permit)

## Next Steps
- Add semgrep rules for the three detection tags
- Add checklist items to master-checklist.md if not present
- Consider adding invariant template for "gateway must not execute arbitrary calldata against token contracts where it holds approvals"

## Decision
Contribution complete: PoC green, case study written, catalog entry added, research logged.