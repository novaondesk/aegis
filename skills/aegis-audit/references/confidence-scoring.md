# Confidence scoring + severity + output tiering

Turns a finding from a vibe into a triage number. Adapted from QuillShield BSA. Apply in
Phase 6 to every finding.

## Confidence formula

```
Confidence = (Evidence × Feasibility × Impact) / FalsePositiveRate     (cap at 99%)
```

**Evidence (0–1)** — how concrete is the vulnerable path?
| 1.0 | 0.7 | 0.4 | 0.1 |
|---|---|---|---|
| Concrete code path, no external deps | Needs a specific but achievable state | Pattern-based, theoretical | Heuristic, no concrete evidence |

**Feasibility (0–1)** — can it actually be triggered?
| 1.0 | 0.7 | 0.4 | 0.1 |
|---|---|---|---|
| PoC confirmed, executes | Needs an achievable contract state | Needs external conditions (oracle infra, MEV) | Practically infeasible |

**Impact (1–5):** 5 = total fund loss / system compromise · 4 = partial loss / privesc ·
3 = griefing / DoS · 2 = info leak · 1 = best practice.

**False-positive rate:** 0.05 known pattern · 0.15 moderate · 0.40 weak · 0.60 heuristic.

### Worked examples
- Reentrancy in `withdraw`, PoC-confirmed: (1.0 × 1.0 × 5) / 0.05 = cap **99%**.
- Spot-price oracle, needs flash-loan infra: (0.7 × 0.4 × 4) / 0.15 ≈ **75%**.
- Theoretical front-run: (0.7 × 0.6 × 3) / 0.30 ≈ **42%**.
- Gas micro-opt: (0.4 × 0.1 × 1) / 0.50 ≈ **8%**.

## Prioritization rules
- Report everything **≥ 10%** confidence; below that goes in an appendix.
- **Never suppress Impact ≥ 4** regardless of confidence — a low-confidence fund-loss path
  is still worth flagging for manual review.
- ≥ 70% → treat as Critical/High and lead the report with it. 30–70% → flag for review.

> **Note — the PoC overrides the score.** A passing Phase-5 PoC pins Evidence and
> Feasibility to 1.0. Aegis findings are PoC-backed by rule, so most real findings land
> high; the score's main job is triaging *Medium hypotheses* you haven't yet proven, and
> ordering the report.

## Severity (Immunefi V2.2) — what you report as the headline
Map impact × privilege × likelihood to: **Critical** (direct theft/freeze of funds, total
insolvency) · **High** (significant fund loss, privesc) · **Medium** (griefing, temporary
DoS, limited loss) · **Low** (best practice, info). Severity is the headline; confidence %
is the qualifier next to it.

## Output tiering (token budget)
Don't spend equal depth on every finding:
- **Critical / High** → full detail + the runnable PoC.
- **Medium** → root cause + exploit path in ≤ 3 steps (no PoC unless cheap).
- **Low / Info** → one line each.
- A dimension with **no attack surface** → write "N/A" and move on; don't pad.
