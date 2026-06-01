# AGENTS.md — How to contribute to the DeFi Bounty Suite

This file is the contract for **AI agents (Nova and others)** and humans working on
this repo. Read it fully before making changes. It defines what "good" looks like so
contributions compound instead of sprawl.

## Mission (don't lose the plot)
Build an **exploit-derived pattern library + semi-automated review suite** that helps a
human find and responsibly disclose smart-contract bugs on bounty platforms. The
durable asset is the **pattern library**, not any one scanner. Every contribution
should make the next bug easier to find.

> There is no autopilot. Tools narrow the haystack; humans find economic/logic bugs.
> If you "find a bug," it is not real until a runnable PoC breaks an invariant.

## Hard rules
1. **Responsible disclosure only.** Work on in-scope bounty targets, public
   post-mortems, or our own deployments. Never probe out-of-scope/live contracts.
2. **No claimed finding without a runnable PoC.** Foundry (EVM) or the chain's native
   harness. A finding doc must link the PoC and state the broken invariant.
3. **Cite primary sources.** Web reporting is a lead, not a fact. Verify $ figures and
   root causes against the protocol post-mortem + on-chain trace before asserting them.
4. **Every new exploit studied must update three places:** a case study in
   `docs/exploits/`, a sharpened item in `checklists/master-checklist.md`, and a
   detection artifact (semgrep rule and/or invariant template). This is the loop.
5. **Don't break the build.** `cd poc && forge build` must pass. PoC tests must pass
   (or be clearly marked `skip` with a reason).

## Repo map (where things go)
| Path | Put here |
|---|---|
| `docs/exploits/` | One case study per incident/class. Use `_TEMPLATE.md`. |
| `docs/vuln-classes/` | Taxonomy (OWASP SC Top 10 2026 + off-chain X-classes). |
| `docs/methodology/` | Industry practice, tooling, sources. |
| `docs/research-plans/` | Time-boxed research day-plans (e.g. Nova's Solana/Base). |
| `checklists/master-checklist.md` | Curated, exploit-justified front-line checks. |
| `checklists/solodit-aggregated-checklist.md` | 370-item EVM backstop (don't hand-edit; re-mine). |
| `checklists/solana-*.md`, `checklists/move-*.md` | Per-ecosystem checklists (to build). |
| `tools/semgrep/` | One rule per extracted pattern; tag it with the checklist ID. |
| `tools/foundry-invariants/` | Reusable invariant templates per vuln class. |
| `poc/` | Runnable Foundry project. Vulnerable + safe contract + exploit test. |
| `targets/` | Per-target recon notes (gitignored source/reports). |
| `research-log/` | Dated log: what you looked at, found, decided. **Append every session.** |

## The contribution loop (follow this every session)
```
1. Pick scope from research-log backlog or an assigned day-plan.
2. RESEARCH   read post-mortems / code / audit reports. Capture sources.
3. REPRODUCE  build a minimal runnable PoC in poc/ (vulnerable + safe + test).
4. DISTILL    write docs/exploits/<name>.md (use _TEMPLATE.md).
5. ENCODE     add/sharpen a checklist item + a semgrep rule and/or invariant.
6. LOG        append research-log/<YYYY-MM-DD>-<topic>.md (done / takeaways / next).
7. COMMIT     small, focused commit (see identity below). Push.
```

## Conventions
- **Commit identity:** `git -c user.name=novaondesk -c user.email=novaondesk@users.noreply.github.com commit`.
  Do **not** add a Claude/AI co-author trailer.
- **Commit messages:** imperative, scoped, explain *why* in the body. One logical change each.
- **PoC project:** Solidity `^0.8.20`, Foundry. Dep: forge-std (run `forge install` if
  `poc/lib/` is empty — `lib/` is gitignored). Name tests `test_<subject>_<behavior>`.
- **Checklist items:** phrase as a yes/no question + the code smell + a real loss it
  maps to. Tag with the source ID where applicable (`SOL-*`, `SC0x`, `X0x`).
- **Markdown links** between docs are relative so they work on GitHub.

## Scope & priorities (current)
- Multi-chain: **EVM (incl. Base) + Solana (Anchor) + Sui/Move.**
- Near-term: go **deep on EVM** (real coded deep-dives) while standing up the
  **Solana** and **Base** research per the day-plans in `docs/research-plans/`.
- Highest-value bug classes: business logic (SC02), oracle (SC03), arithmetic/precision
  (SC07). These resist automation — spend human time here.

## Definition of done for a contribution
- [ ] PoC builds and tests pass (or skipped-with-reason).
- [ ] Case study written from `_TEMPLATE.md` with primary sources.
- [ ] Checklist + detection artifact updated (the loop's step 5).
- [ ] `research-log/` appended.
- [ ] Committed with the right identity and pushed.
