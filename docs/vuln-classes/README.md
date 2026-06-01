# Vulnerability Taxonomy

Our working taxonomy is anchored to the **OWASP Smart Contract Top 10 (2026)**,
which was built from 122 deduplicated 2025 incidents totaling ~$905M in pure
smart-contract losses. We extend it with the off-chain/governance classes that
dominated 2026 losses but fall outside pure contract code.

## OWASP Smart Contract Top 10 — 2026

| ID | Class | One-liner | 2026 $ weight* |
|----|-------|-----------|----------------|
| SC01 | **Access Control** | Unauthorized callers invoke privileged functions / modify critical state | ~$953M (dominant) |
| SC02 | **Business Logic** | Design flaws in lending/AMM/governance that break economic rules | high |
| SC03 | **Price Oracle Manipulation** | Weak oracles let attackers skew reference prices for borrow/swap | high |
| SC04 | **Flash-Loan Facilitated** | Uncollateralized loans magnify a latent bug within one tx | ~$34M |
| SC05 | **Lack of Input Validation** | Missing validation of user/admin/cross-chain inputs corrupts state | med |
| SC06 | **Unchecked External Calls** | Failures/reverts/callbacks not handled safely | med |
| SC07 | **Arithmetic Errors** | Precision/rounding bugs in share & interest math siphon value | ~$64M |
| SC08 | **Reentrancy** | External call re-enters before state update → repeated withdrawals | ~$36M |
| SC09 | **Integer Overflow/Underflow** | Arithmetic exceeds limits, breaks invariants | (mostly killed by ^0.8) |
| SC10 | **Proxy & Upgradeability** | Misconfigured proxies let attackers seize the implementation | med |

\* Approximate, based on 2025–2026 loss attributions across OWASP/Hacken/Chainalysis reporting. See sources in `docs/methodology/sources.md`.

## Extension classes (the "code is perfect, process isn't" bugs)

These produced the *largest* single losses of 2026 even though they aren't contract
code bugs. They matter for target selection and for protocols where governance/config
is in scope.

| ID | Class | One-liner | Example |
|----|-------|-----------|---------|
| X01 | **Cross-chain / bridge trust config** | Single-DVN / single-verifier messaging = single point of failure | Kelp DAO rsETH, $292M (Apr 2026) |
| X02 | **Governance social engineering** | Off-chain compromise of signers/operators (DPRK-style) | Drift Protocol, $285M (Apr 2026) |
| X03 | **Supply-chain / signing infra** | Compromised frontend/signing pipeline, not the contract | Bybit, ~$1.4B (2025) |

## How we use this

Each class has a dedicated checklist in `checklists/` with concrete code smells and
review questions. During TRIAGE we map automated findings to these IDs; during
REVIEW we walk each applicable checklist by hand.

## Priority for a code-focused hunter

If the goal is *findable, code-level* bounty bugs (vs. ops failures we can't touch),
rank effort roughly: **SC02 (logic) ≈ SC03 (oracle) ≈ SC07 (arithmetic) > SC01
(access control) > SC08 (reentrancy) > rest.** The top three are where modern,
already-audited protocols still bleed, because tools can't read economic intent.
