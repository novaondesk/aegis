# Output format — coverage table, finding, report

Use these exact shapes in Phase 6 so reports are consistent and the coverage claim is
explicit.

## 1. Coverage table (lead with this)

Proves *what was checked*, not just what was found. One row per candidate catalog entry
plus the REVIEW engines.

```
Target: <name> (<chain>, archetype: <…>)   Catalog coverage: N/N candidate entries evaluated

┌──────────────────────────────┬─────────┬──────────────────────────────────────────────┐
│ check                        │ verdict │ note                                         │
├──────────────────────────────┼─────────┼──────────────────────────────────────────────┤
│ erc4626-inflation            │ HIGH    │ totalAssets() reads balanceOf(this); no offset│
│ read-only-reentrancy         │ N/A     │ no pool view consumed as an oracle           │
│ balancer-v2-rounding         │ MED     │ scaled balances; rounding dir unverified     │
│ … (every candidate entry)    │ …       │ …                                            │
│ ENGINE: state-invariant      │ HIGH    │ redeem() breaks total = Σ shares             │
│ ENGINE: semantic-guard       │ LOW     │ all setters consistently onlyOwner           │
└──────────────────────────────┴─────────┴──────────────────────────────────────────────┘
```

Verdicts: **HIGH** (all preconditions hold → prove it) · **MED** (most hold → investigate) ·
**LOW** (weak signal) · **N/A** (chain/archetype/precondition absent).

## 2. Finding block (one per PoC-backed finding)

```
### [F-1] <Title>
Severity: Critical | High | Medium | Low      Confidence: <N>%
Catalog: <entry-id or "novel (engine: state-invariant)">
Location: Contract.sol:L42-L60, functionName()

Root cause: <1–2 sentences — complete the entry's root_cause statement for THIS target>
Broken invariant: <the property that fails>

Exploit (≤5 steps):
1. …
2. …

Impact: <1 sentence, quantified — e.g. "drains the full USDC reserve for ~0 cost">

Fix (lead with this):
<concrete code diff or 1–2 sentence change; reference the Safe<X> variant that proves it>

PoC: poc/test/<X>.t.sol  →  cd poc && forge test --match-contract <X> -vv
  - test_<x>_isExploited   ✓ (attacker profits / invariant breaks)
  - test_<x>_resistsAttack ✓ (fix holds)
```

Tier by severity (see `confidence-scoring.md`): full block for Critical/High; Medium gets
root cause + ≤3-step exploit; Low/Info is one line.

## 3. Report skeleton

```markdown
# Aegis audit — <target>

## Scope & coverage
<scope block>            <coverage table>

## Findings (PoC-backed)
[F-1] …   [F-2] …        # ordered by severity then confidence

## Hypotheses (unproven, for manual review)
- <MED rows without a PoC yet — what to check>

## Remediation summary
| # | Finding | Fix | Proven by |
|---|---------|-----|-----------|
| F-1 | … | … | Safe<X> ✓ |

→ Hand the Remediation summary to `aegis-defender` for release-gating.
```

## Verification before you ship the report
- [ ] Every candidate catalog entry has a verdict row.
- [ ] Every finding has file:line, a passing PoC command, and a concrete fix.
- [ ] No placeholder text (`<…>`, "TODO") remains.
- [ ] Severity + confidence on every finding; report ordered by them.
