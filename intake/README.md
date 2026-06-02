# intake/ — Onyx's review queue

This is the **staging area** where Onyx (the Hermes agent) drops recompiled exploit
work for review. Nothing here is canonical yet. A human/Claude reviews each item,
then **promotes** it into the real repo (`docs/exploits/`, `catalog/exploits.yaml`,
`checklists/`, `poc/`) and pushes. Onyx should *only ever write inside `intake/`*.

The work order Onyx follows: **[`../docs/research-plans/onyx-exploit-recompile.md`](../docs/research-plans/onyx-exploit-recompile.md)**.

## Scope (hard filter): software bugs only
Accept only **code-level** vulnerabilities (OWASP SC01–SC10). **Reject** and skip:
private-key/multisig compromise, social engineering, governance takeover, frontend/
DNS/supply-chain, rug pulls, and pure ops failures. If the root cause isn't a bug a
reviewer could find by reading the contract, it's out of scope.

## What goes where
```
intake/
├── backlog.md            # the tracking sheet — every candidate + its status
├── case-studies/<id>.md  # draft case study (use docs/exploits/_TEMPLATE.md)
├── catalog/<id>.yaml     # draft catalog entry (one `exploits:` item, catalog schema)
├── techniques/<id>.md    # the reusable detection technique distilled from the bug
└── poc-drafts/<id>/      # (EVM, optional) minimal Vulnerable+Safe+test Foundry trio
```
`<id>` = kebab-case `protocol-vuln-YYYY` (e.g. `euler-donation-liquidation-2023`),
matching across all folders so an item's files are easy to find together.

## Definition of done for one intake item
- [ ] `backlog.md` row updated to `review` with the source links filled in.
- [ ] `case-studies/<id>.md` written from the template, with **primary sources**
      (post-mortem + attack tx) and the vulnerable code excerpt.
- [ ] `catalog/<id>.yaml` is a valid catalog entry with **checkable `applies_when`
      preconditions** (the reusable part — not a retelling of the story) and parses:
      `python3 -c "import yaml; yaml.safe_load(open('intake/catalog/<id>.yaml'))"`.
- [ ] `techniques/<id>.md` states how to *detect this class on a new target*
      (preconditions to grep for, an invariant to fuzz, a semgrep/slither idea).
- [ ] No scope violations (software-only), no duplicate of an existing catalog entry.

## Review → promote (done by Claude, not Onyx)
1. Verify scope, sources, and that the catalog fragment parses + preconditions are real.
2. Move `case-studies/<id>.md` → `docs/exploits/<id>.md`; merge `catalog/<id>.yaml`
   into `catalog/exploits.yaml`; fold the technique into `checklists/master-checklist.md`
   and/or a `tools/semgrep` rule; (EVM) promote a `poc-drafts/` trio into `poc/`.
3. Flip the `backlog.md` row to `promoted`, commit as `novaondesk`, push.

See [`../AGENTS.md`](../AGENTS.md) and [`../catalog/README.md`](../catalog/README.md) for
the canonical formats Onyx's drafts must match.
