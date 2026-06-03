---
title: Aegis
---

**Exploit-catalog-driven smart contract security auditing.** Aegis evaluates a target against a
curated catalog of *studied, real-world DeFi exploits* — find the vulnerability **and prove the fix**
before an attacker does. The durable asset is the catalog of structured detectors, not any one
scanner; auditing means sweeping a target against every known attack and proving each hit with a
runnable PoC.

- **Repo:** [github.com/novaondesk/aegis](https://github.com/novaondesk/aegis)
- **The catalog:** [`catalog/exploits.yaml`](https://github.com/novaondesk/aegis/blob/main/catalog/exploits.yaml) — 27 detectors (25 with runnable PoCs)
- **Skills:** `aegis-audit` (red team) · `aegis-defender` (blue team)

## Proof it works

**[→ Aegis vs. the Ethernaut wargame](https://github.com/novaondesk/aegis/blob/main/docs/ethernaut-wargame.md)** — Aegis solves OpenZeppelin's
Ethernaut CTF **5/5** using only its catalog sweep. Each level's bug is identified by an
`applies_when` match against a detector mined from a real hack, then proven by exploiting the real
level contract. Read it to see exactly which catalog entries were used.

**Real-incident fork replays** ([`sim/`](https://github.com/novaondesk/aegis/tree/main/sim)) — the
same detectors, proven against live mainnet state at the pre-hack block:

| Incident | Detector | Result on a mainnet fork |
|---|---|---|
| Socket Gateway (2024) | `approval-drain-arbitrary-call` | drains a real victim's ~656k USDC |
| Audius (2022) | `proxy-storage-collision` | seizes governance, drains ~18.56M AUDIO |
| DAO Maker (2021) | `unprotected-privileged-fn` | unprotected init drains 5.76M DERC |
| Beanstalk (2022) | `beanstalk-governance-flashloan` | ~$1B flash loan → ~$42M profit |

## How it works

1. **RECON & SCOPE** — pull source (or decompile), pin chain + archetype.
2. **SWEEP** — evaluate the target against every catalog detector's `applies_when` → ranked hypotheses.
3. **REVIEW** — general engines + exploit-derived checklists for novel bugs.
4. **PROVE** — a Foundry PoC that breaks the entry's invariant (model in [`poc/`](https://github.com/novaondesk/aegis/tree/main/poc), or on a real fork in [`sim/`](https://github.com/novaondesk/aegis/tree/main/sim)).
5. **SCORE & REPORT**, then **PROTECT** with a fix proven by a `Safe<X>` PoC.

## Catalog classes covered

OWASP SC Top 10 (2026): access control (SC01), logic (SC02), oracle/price manipulation (SC03),
reentrancy (SC08), randomness (SC09), arithmetic/precision (SC07), unsafe external calls (SC05), and
cross-chain/bridge classes — each entry justified by a real incident with a loss attached.

---
<sub>Defensive / responsible-disclosure use only. See the
[repository](https://github.com/novaondesk/aegis) for the full catalog, case studies, checklists, and
tooling.</sub>
