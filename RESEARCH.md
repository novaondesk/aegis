# RESEARCH.md — sourcing new exploits and turning them into catalog detectors

You are an agent growing **Aegis**. The catalog is the durable asset; your job is to **find
recent, real exploits, distill each into a detector, and prove it with a runnable PoC**. This
file tells you *where to look*, *what to pick*, and *how to convert a hack into a catalog entry*.

Read [`AGENTS.md`](AGENTS.md) first (the contributor contract + the four-places loop) and
[`CONTINUE.md`](CONTINUE.md) (current state + exact build/commit/push mechanics). This file is the
**research front-end** to that loop.

---

## The mission, in one line
> Find a real exploit → understand its **root cause** (the missing/incorrect invariant) → model
> it minimally in Solidity → prove `Vulnerable<X>` breaks and `Safe<X>` holds → add a detector so
> the next audit catches the *class*, not just this instance.

A hack is only useful to Aegis once it's a **generalizable detector** with checkable
`applies_when` preconditions and a green PoC. A one-off "X got hacked" note is not a contribution.

---

## Where to find exploits (sources, by purpose)

### A. Discovery — "what just got hacked?" (scan these for fresh material)
- **web3isgoingreat.com** — Molly White's running chronicle of crypto incidents. Best for
  *spotting* new events fast and getting the plain-English summary + primary links.
- **rekt.news** — exploit post-mortems with technical depth; the **Leaderboard**
  (rekt.news/leaderboard) ranks by loss size. Great for the "biggest, most-studied" cases.
- **DeFiLlama Hacks** — https://defillama.com/hacks — quantified, filterable loss dashboard
  (date, chain, technique, amount). Good for triage by size/recency/archetype.
- **SlowMist Hacked** — https://hacked.slowmist.io — searchable database of incidents with
  classification (contract bug vs. key leak vs. rug). Filter to *contract vulnerabilities*.
- **Real-time alerts (X/Twitter):** PeckShield, CertiK Alert, SlowMist, BlockSec, Cyvers —
  first to post the attack tx within minutes.

### B. Root-cause analysis — "why did it work?" (the part you must understand)
- **Immunefi** — https://immunefi.com + the "Hack Analysis" series on
  https://medium.com/immunefi — detailed, PoC-grade breakdowns. Also their disclosed bug
  reports are gold (a *fixed* bug with a writeup = a ready-made detector).
- **Official post-mortems** — the protocol's own incident report (like the TAC one below).
  Always prefer primary sources; they state the exact missing check.
- **BlockSec Phalcon Explorer** (https://app.blocksec.com/explorer) / **Tenderly** — decode the
  attack transaction step by step to reconstruct the exact call path.
- **Chainalysis / SlowMist** post-mortems — for laundering trail + confirmation of method.
- **OpenZeppelin post-mortems thread** —
  https://forum.openzeppelin.com/t/list-of-ethereum-smart-contracts-post-mortems/1191

### C. PoC reference & technique — "how do I reproduce it?"
- **DeFiHackLabs** — https://github.com/SunWeb3Sec/DeFiHackLabs — **the** reference: hundreds of
  real hacks reproduced in **Foundry**. If your target is already there, study their PoC for the
  technique, then write the *generalized* `Vulnerable/Safe` version for our catalog (don't just
  copy — we want the class + a fix, not a single-tx replay). Their `academy/` has PoC-writing
  lessons (oracle manipulation, reentrancy, etc.).
- **`sim/`** (this repo) — for a *deployed* target, prove on a **fork of real state**: exploit
  the live contract + its real deps; only the attacker is deployed. See [`docs/fork-simulation.md`](docs/fork-simulation.md).

### D. Taxonomy — "what class is this?"
- **OWASP Smart Contract Top 10 (2026)** — https://owasp.org/www-project-smart-contract-top-10/ —
  map every finding to an `SCxx` class (we tag detectors with these).
- **Solodit** — https://solodit.xyz — aggregated Code4rena / Sherlock / Cantina findings;
  search by keyword to see how a class recurs across audits (sharpens `applies_when`).
- **Audit contests** — Code4rena (https://code4rena.com/reports), Sherlock
  (https://audits.sherlock.xyz), Cantina — recurring high/medium findings are excellent
  *class* detectors even without a headline hack.

---

## What makes a good catalog candidate
Pick exploits that are:
1. **Root-cause-clear** — you can name the exact missing/incorrect invariant (not "complex bug").
2. **EVM-modelable** — reproducible in a minimal Foundry PoC. Non-EVM (TON/Solana/Move) bugs are
   fine *if* the root cause is portable — model the *logic* in Solidity (see the TAC example).
3. **Generalizable** — the bug is a *class* that will recur (a missing provenance check, a
   donation-manipulable price, a code-hash-without-binding check), not a typo unique to one repo.
4. **Not already covered** — grep `catalog/exploits.yaml` for the class first; if it exists,
   add a `variant` or sharpen `applies_when` instead of duplicating.
5. **Bounty-relevant** — a reviewer could realistically have caught it; it maps to live targets.

Prefer **recent** (last ~12 months) and **high-loss / high-frequency** cases first.

---

## The loop — turn one exploit into a contribution (the four places + PoC)
Per [`AGENTS.md`](AGENTS.md), every studied exploit updates **four places**, plus a green PoC:

1. **Study** → `docs/exploits/<id>.md` (use `docs/exploits/_TEMPLATE.md`): loss, chain, class,
   primary sources, the vulnerable code (reconstructed), the root cause, the fix, attack walkthrough.
2. **Detector** → an entry in `catalog/exploits.yaml` (schema in `catalog/README.md`): `id`,
   `class` (SCxx), `archetypes`, **checkable `applies_when`**, `probes`, `invariant`, `root_cause`,
   `variant_queries`, `doc`, `poc`, `poc_cmd`, `checklist`, `semgrep`, `sources`. Start
   `status: studied`; flip to `coded` once the PoC is green.
3. **Checklist** → a sharpened item in `checklists/master-checklist.md` (a yes/no a reviewer asks).
4. **Detection artifact** → a `tools/semgrep/<rule>.yaml` and/or an invariant template, when the
   bug is statically/structurally detectable. (If it's "absence of a check," say so — static tools
   can't see missing code; the value is the checklist item + PoC.)

**Then prove it** under `poc/`:
- `poc/src/<area>/<X>.sol` — a **minimal** `Vulnerable<X>` modeling the exact root cause, and a
  `Safe<X>` with the fix. Keep it small; model the *one* flawed invariant, not the whole protocol.
- `poc/test/<X>.t.sol` — a test that (a) demonstrates the exploit succeeds on `Vulnerable<X>`, and
  (b) shows `Safe<X>` defeats the same exploit (and still accepts legitimate use).
- Run it green:
  ```bash
  cd poc && forge test --match-contract <X> -vv
  ```
  **No claimed finding without a runnable PoC.** Then set the catalog entry's `poc`/`poc_cmd` and
  `status: coded`, and bump the count in `docs/the-catalog.md` / `docs/pocs.md`.

### How to write the PoC (method)
1. From the post-mortem, write the **one sentence invariant** the exploit violated
   (e.g. "shares must be priced fairly; no external donation shifts price-per-share").
2. Model only what's needed to break it. Use `forge-std/Test`, `makeAddr`, `vm.prank`,
   `vm.expectRevert`. Mock tokens via `poc/test/mocks/`.
3. Make the vulnerable assertion the *exploit outcome* (attacker gained X / bypassed Y).
4. Make the safe test assert the exploit now **reverts** *and* a legitimate path still works.
5. For non-EVM bugs, port the **logic** (see TAC: TON jetton minter-binding → Solidity storage +
   `codehash`), and say so in the doc.

### Commit & push (exact mechanics — see CONTINUE.md)
Canonical dirs (`catalog/`, `poc/`, `docs/`, `checklists/`, `tools/`) are gated; prefix the commit
and push with the env flags, commit as `novaondesk` with **no AI co-author trailer**:
```bash
AEGIS_PROMOTE=1 git -c user.name=novaondesk -c user.email=novaondesk@users.noreply.github.com \
  commit -m "poc: <exploit> — <root cause> (N green)"
AEGIS_PUSH=1 git push origin main
```
Small, focused commits; explain *why* in the body. **Push after every commit.**

---

## Worked example (do it like this)
**TAC Bridge — Jetton Wallet Code-Hash Verification Bypass** ($2.85M, 2026-05-11):
- Source: official post-mortem (https://tac.build/blog/post-mortem-report-tac-bridge) → study at
  `docs/exploits/tac-bridge-jetton-impersonation-2026-05-11.md`.
- Root cause: bridge authenticated inbound wallets by **code hash only**, never verifying the
  wallet's **minter/master binding** → an impersonator with the canonical code hash but an
  attacker minter was accepted.
- Detector: `tac-bridge-jetton-impersonation` in `catalog/exploits.yaml` (class SC02).
- PoC (TON logic ported to EVM): `poc/src/bridge/JettonImpersonation.sol` +
  `poc/test/JettonImpersonation.t.sol` — minter in **storage** ⇒ every wallet shares one
  `codehash`; `VulnerableJettonBridge` accepts the impersonator and credits 302M fake BLUM;
  `SafeJettonBridge` adds the minter-provenance check and rejects it.
  ```bash
  cd poc && forge test --match-contract JettonImpersonation -vv   # 3 passed
  ```
That's a complete contribution: discovery → root cause → four places → green PoC → pushed.
