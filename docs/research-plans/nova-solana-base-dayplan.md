# Nova Research Day-Plan — Solana + Base

A full day of autonomous research, split into two tracks. **Morning = Solana
(Rust/Anchor)** — net-new territory for the suite. **Afternoon = Base (EVM/OP-Stack
L2)** — our EVM suite applies, plus L2-specific angles.

Follow the contribution loop in [`../../AGENTS.md`](../../AGENTS.md). Every block ends
with a committed artifact in the repo — research that doesn't land as a checklist item,
detector, PoC, or log entry didn't happen. Append findings to `research-log/` as you go.

> Rules: responsible disclosure only; no finding without a runnable PoC; verify $/root
> cause against primary sources. Commit as `novaondesk`, no AI co-author trailer.

---

## TRACK A — Solana / Anchor (morning, ~4h)

Goal by lunch: a **`checklists/solana-anchor-checklist.md`** seeded from the canonical
Sealevel attack classes, at least **one runnable Anchor PoC**, and a shortlist of live
Solana bounty targets.

### A1 (45m) — Map the Solana attack surface
Read and take structured notes (capture URLs in `docs/methodology/sources.md`):
- `coral-xyz/sealevel-attacks` (the canonical vulnerable/secure example pairs).
- Neodyme "Solana security" workshop + their common-pitfalls posts.
- Anchor docs: account constraints (`Signer`, `Account`, `has_one`, `seeds`, `bump`,
  `init`, `init_if_needed`, `close`), and the discriminator model.
- Helius / sec3 / OtterSec blog posts on real Solana exploits (e.g. Mango Markets
  oracle manipulation, Cashio infinite-mint via account validation, Crema, Nirvana).
**Deliverable:** notes file + sources appended.

### A2 (75m) — Draft the Solana/Anchor checklist
Create `checklists/solana-anchor-checklist.md` covering the core classes (each as a
yes/no question + the code smell + a real exploit):
- **Missing signer check** — privileged action without `Signer`/`is_signer`.
- **Missing owner check** — deserializing an account not owned by the program.
- **Account confusion / type cosplay** — no discriminator/type check; `Account<T>` vs
  raw `AccountInfo`. *cf. Cashio (fake collateral accounts) → infinite mint.*
- **Missing `has_one` / account-relationship** — unlinked authority/vault/mint.
- **Arbitrary CPI** — invoking a program id from an unchecked account.
- **PDA bump canonicalization** — `create_program_address` w/ user bump vs
  `find_program_address`; unvalidated `seeds`/`bump`.
- **Integer overflow** — Rust release wraps; require `checked_*` / `overflow-checks`.
- **Reinitialization** — `init_if_needed` abuse; re-init to reset state.
- **Account closing / revival** — lamports drained but data not zeroed; rent revival.
- **Duplicate mutable accounts** — same account passed twice to bypass checks.
- **Sysvar / oracle spoofing** — unvalidated sysvar address; spot oracle (*Mango*).
**Deliverable:** committed checklist with ≥12 items.

### A3 (75m) — Build one runnable Anchor PoC
Pick the single highest-signal class (recommend **account confusion / missing owner
check** — the Cashio pattern). Set up a minimal Anchor program under
`poc-solana/` (mirror the EVM `poc/` shape: vulnerable + secure + a test that drains
the vulnerable one). Use `anchor test` (or `cargo test-sbf`). If the toolchain
(`anchor`, `solana`) isn't installed, document the exact install + leave the program +
test written and clearly marked `// TODO: run once toolchain installed`.
**Deliverable:** `poc-solana/` with vulnerable+secure program and an exploit test;
a `docs/exploits/solana-account-confusion.md` from `_TEMPLATE.md`.

### A4 (30m) — Target scouting + log
- Browse Immunefi for **live Solana programs** in scope; note 3–5 with payout tier,
  scope, and complexity in `targets/` (one stub file each).
- Append `research-log/<date>-solana.md`: done / takeaways / next.

---

## TRACK B — Base (afternoon, ~4h)

Base is an OP-Stack EVM L2 — the entire existing EVM suite (`master-checklist.md`,
semgrep, Foundry) applies directly. The new value is **L2/OP-Stack-specific** angles
and a live dry-run.

Goal by EOD: a **`checklists/base-l2-addendum.md`**, the automated suite run against a
**real in-scope Base target**, and a triage write-up.

### B1 (45m) — Map Base / OP-Stack specific risks
Read + capture sources:
- OP Stack docs: L1↔L2 messaging (`CrossDomainMessenger`), **address aliasing**,
  deposit/withdrawal flow, the **fault-proof / 7-day withdrawal** window.
- Chainlink L2 **sequencer-uptime feed** pattern (stale price during sequencer
  downtime) — already partially in `master-checklist` `SOL-Defi-Oracle-4`.
- `block.number`/`block.timestamp` semantics on L2 (per-L2 block time, not L1).
- Cheap gas → griefing/unbounded-loop economics shift; reorg/finality differences.
- Native USDC vs bridged USDC.e assumptions; OP-Stack predeploys.

### B2 (60m) — Write the Base L2 addendum checklist
Create `checklists/base-l2-addendum.md` (deltas on top of the EVM checklist):
- [ ] Does the protocol check the **sequencer-uptime feed** before trusting prices?
- [ ] Cross-domain messages: is `xDomainMessageSender` verified? aliasing handled for
      L1→L2 callers?
- [ ] Any reliance on `block.number` as a wall-clock or for cross-chain timing?
- [ ] Withdrawal/finalization assumptions (7-day window) baked into accounting?
- [ ] Gas-cost assumptions that hold on L1 but break with cheap L2 gas (spam/griefing)?
- [ ] Token assumptions: native vs bridged (decimals, mint authority, FoT)?
**Deliverable:** committed addendum.

### B3 (90m) — Live dry-run on a real Base target
- Pick one **in-scope** Base bounty target (candidates to check for active programs:
  Aerodrome, Moonwell, Morpho-on-Base, Extra Finance — confirm scope on Immunefi).
- RECON: pull verified source into `targets/<name>/src/` (gitignored), map
  architecture + trust boundaries.
- TRIAGE: run `slither` (config in `tools/slither/`) + `semgrep --config tools/semgrep`.
- REVIEW: walk the relevant archetype playbook + the Base addendum by hand; record any
  hypotheses (no live testing — model them).
**Deliverable:** `targets/<name>/triage.md` — architecture notes, tool output summary,
ranked hypotheses (even if all turn out non-issues, the negative result is logged).

### B4 (30m) — Synthesize + log
- Any hypothesis worth a PoC? Stub it in `poc/` for tomorrow.
- Append `research-log/<date>-base.md`: done / takeaways / next; update backlog.

---

## End-of-day definition of done
- [ ] `checklists/solana-anchor-checklist.md` (≥12 items) committed.
- [ ] `checklists/base-l2-addendum.md` committed.
- [ ] ≥1 Solana PoC written (run if toolchain available) + its case study.
- [ ] ≥1 live Base target triaged with a written `triage.md`.
- [ ] `targets/` has 3–5 Solana + 1 Base target stubs.
- [ ] Two `research-log/` entries appended; backlog updated.
- [ ] Everything pushed.

## Stretch (if ahead)
- Second Solana PoC (PDA bump canonicalization or arbitrary CPI).
- Wire the EVM `VaultShareInvariant` template into a runnable stateful invariant.
- Add Solana detector ideas to `tools/` (e.g. semgrep-for-Rust or notes on `cargo
  geiger` / `x-ray` / sec3 `soteria`).
