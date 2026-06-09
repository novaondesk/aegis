# catalog/ — the Aegis exploit catalog

`exploits.yaml` is the **single source of truth** for Aegis's core capability:
*evaluate a target against every known, studied exploit.* It turns each deep-dive
case study in [`../docs/exploits/`](../docs/exploits/) into a structured **detector**
an agent (or human) can run mechanically against a target.

This is the "better approach": instead of a freeform "go audit this," the
[`aegis-audit`](../skills/aegis-audit/SKILL.md) skill loads this catalog and performs a
deterministic **sweep** — for every entry it evaluates the `applies_when`
preconditions against the target's source, ranks the matches, and only then spends
human/agent time proving the top hypotheses with a PoC.

```
target source ──► for each catalog entry:
                    evaluate applies_when ─► match? ─► rank ─► probe ─► PoC ─► finding
```

## Why a catalog (not just docs)

- **Coverage you can prove.** "We checked all N known exploits against this target"
  is a checklist, not a vibe. Nothing studied gets silently skipped.
- **Fast scoping.** `archetypes` + `chains` filter the catalog to the entries that
  could possibly apply before any deep reading.
- **Machine-consumable.** One YAML file other tooling can read; the prose lives in
  the linked case study.
- **It compounds.** Every new exploit studied adds one entry → every future target is
  automatically checked against it.

## Entry schema

| Field | Meaning |
|---|---|
| `id` | kebab-case unique id (matches `docs/exploits/<id>*.md` where possible) |
| `name` | human title |
| `status` | `coded` (runnable PoC), `studied` (full detector, PoC pending), or `documented` (case study only). Lifecycle: documented → studied → coded. `studied`/`coded` additionally require `root_cause` + `variant_queries` + `detection`. |
| `class` | OWASP SC Top-10 2026 ids + X-classes (see [`../docs/vuln-classes/`](../docs/vuln-classes/)) |
| `chains` | `evm` \| `solana` \| `sui-move` \| `aptos-move` \| `cosmwasm` \| `near` \| `ton` \| `tron` \| `polkadot` \| `multi` |
| `archetypes` | target shapes it applies to — used to scope the sweep quickly |
| `loss_usd` / `date` | headline loss & incident date (or `recurring` for a class) |
| `summary` | one paragraph: what the attacker did and why it worked |
| `root_cause` | one-line variant-analysis statement — "happens because *X* reaches *sensitive op* without *protection*." The sweep's true/false-positive judge. |
| `applies_when` | **preconditions** — checkable statements about the target. The more that hold, the higher the hypothesis ranks. |
| `probes` | concrete ways to confirm on the target (grep / semgrep / manual) |
| `variant_queries` | grep/semgrep patterns (the abstraction ladder) to hunt this bug's *family* across a target; combine into one regex per sweep pass |
| `invariant` | the property that should hold; the exploit breaks it |
| `detection.static_flags` | does slither/semgrep reliably catch it? (usually `false`) |
| `doc` / `poc` / `poc_cmd` | deep-dive doc, runnable PoC, and how to run it |
| `fork_poc` | *(optional)* external mainnet-fork replay of the real incident (e.g. a DeFiHackLabs path) — realism backing for the minimal model |
| `checklist` / `semgrep` | relevant `checklists/master-checklist.md` class ids and `tools/semgrep` rule ids |
| `sources` | primary references |

## Versioning

The top-level `version:` field is the **schema version** — it tracks the *shape* of an
entry (the fields above), not the repo release or the entry count. It bumps only when the
schema changes in a backward-incompatible way (a renamed/removed field, a new required
field). It is deliberately decoupled from the repo's `vX.Y.Z` release tags, which move
every time entries are added. `tools/validate_catalog.py` enforces the current schema.

## How the sweep ranks a match

A target "matches" an entry when its `applies_when` preconditions hold. Rank by how
many hold and how load-bearing they are:

- **High** — all preconditions hold and the archetype matches exactly. Write a PoC.
- **Medium** — most hold; one is unverified. Investigate to confirm/deny.
- **Low / N/A** — archetype or chain doesn't match, or a key precondition is absent.

A match is a **hypothesis, not a finding.** Per the hard rules, nothing counts until a
runnable PoC breaks the stated `invariant`.

## Adding an entry (do this for every exploit studied)

1. Write the deep-dive in `../docs/exploits/<id>.md` (use `_TEMPLATE.md`).
2. Add a catalog entry here with **checkable** `applies_when` preconditions, a one-line
   `root_cause` statement, and `variant_queries` (the grep family to hunt it) — the part
   that makes it reusable. Avoid restating the story; encode the *signals*.
3. Link the `checklist` class and any `semgrep` rule; add the rule if it's new. If a
   mainnet-fork replay of the incident exists (e.g. DeFiHackLabs), link it as `fork_poc`.
4. If you coded a PoC, set `status: coded` + `poc`/`poc_cmd`.
5. Keep it parseable: `python3 -c "import yaml; yaml.safe_load(open('catalog/exploits.yaml'))"`.

See [`../AGENTS.md`](../AGENTS.md) for the full contribution loop.
