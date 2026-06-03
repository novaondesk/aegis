# Sweep rigor — root-cause statements, abstraction ladder, scalable probing

The SWEEP is only as good as its discipline. Adopted from Trail of Bits variant analysis.
The point: turn each catalog entry into a **precise, false-positive-bounded hunt**, and run
it so the tool-call count stays bounded even on a large target.

## 1. Lead with the root-cause statement

Every catalog entry carries a `root_cause` field in the form:

> "This exploit happens because **[UNTRUSTED/UNCONSTRAINED THING]** reaches
> **[SENSITIVE OPERATION]** without **[REQUIRED PROTECTION]**."

That statement *is* your search target and your true/false-positive judge. Before grepping,
restate the target's version of it. A grep hit only matters if it can complete that
sentence on *this* target.

Examples (from the catalog):
- erc4626-inflation: "share price reaches a depositor's round-down mint without a virtual
  offset / dead-shares floor."
- loopscale-ratex-cpi: "a borrower-supplied program/address reaches the rate read without
  being constrained to a known id."
- beanstalk-governance-flashloan: "flash-loaned voting power reaches `emergencyCommit`
  without a proposal-creation snapshot."

## 2. Climb the abstraction ladder (don't start generic)

For each entry's `variant_queries`, generalize **one element at a time** and review every
new match before going broader. Stop when the false-positive rate exceeds ~50%.

| Level | Pattern | Matches | Use |
|---|---|---|---|
| 0 — exact | the literal vulnerable construct | 1 (or 0) | baseline; confirms the shape exists |
| 1 — variable | metavariables for names | copy-paste variants | find duplicated code |
| 2 — structural | the dangerous structure, any names/values | the bug *family* | the real catch |
| 3 — semantic | all related constructs (see below) | broad | only if FP rate stays < 50% |

**Enumerate related constructs at Level 3.** A bug around `isAuthenticated` may also live in
`isActive` / `isAdmin` / `onlyOwner`; an oracle read via `getReserves()` may also be
`slot0()`, `latestAnswer()`, `price()`, `get_virtual_price()`. List the family before you
search, or you'll miss variants.

## 3. Probe so it scales (bounded tool calls)

The agent will silently shortcut if you ask for N files × M patterns. Don't.

- **Combine** all of an entry's `variant_queries` (and ideally a whole archetype's entries)
  into **one alternation regex**, Grep the codebase **once**, then filter hits by file and
  by `root_cause`. One pass, not a loop.
  ```
  Grep:  delegatecall|selfdestruct|tx\.origin|slot0\(|getReserves\(|latestAnswer\(|_upscale|min_amount_out
  then:  exclude **/test/**, **/mock/**, **/lib/**  →  Read context around survivors
  ```
- **Batch** any subagent work into groups (10–20 files per Task), never one subagent per
  file/function.
- Apply the **10,000-file test**: if the codebase were huge, does your plan stay bounded?
  If not, restructure before running.

## 4. Triage every match

For each survivor, record: location (file:line, function), can it complete the `root_cause`
sentence? (true/false positive), is it reachable with attacker-controlled input?, and a
HIGH/MED/LOW/N/A rank. Then it graduates to Phase 4 (HYPOTHESIZE) only if it's a plausible
true positive.

## 5. Critical pitfalls (these cause missed bugs)

1. **Narrow scope** — searching only the module where you expect the bug. Always Grep the
   whole repo root.
2. **Pattern too specific** — only the exact symbol from the case study. Use the construct
   family (step 2, Level 3).
3. **Single manifestation** — one root cause has many shapes (inverted condition,
   null-equality bypass, doc/code mismatch). List manifestations before searching.
4. **Skipping edge cases** — test the probe mentally against zero/dust/`null`/empty/boundary
   inputs, not just the "normal" path.
