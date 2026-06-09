# Tools — the automated first-pass

These narrow the haystack. They do **not** find logic/economic bugs (the valuable
ones). Their job: clear the noise so human review time goes to `checklists/` items
marked 👁.

## Suggested local stack

```bash
# Static
pipx install slither-analyzer        # primary static analyzer
pipx install mythril                 # symbolic, deeper/slower
cargo install aderyn                 # Cyfrin Rust analyzer

# Dynamic / PoC
curl -L https://foundry.paradigm.xyz | bash && foundryup   # forge: tests, fuzzing, invariants
# echidna / medusa via their release binaries or docker

# Pattern rules
pipx install semgrep                 # custom Solidity rules (tools/semgrep/)

# Source acquisition
# cast (ships with foundry) + block explorer API keys for pulling verified source
```

## Pipeline (RECON → TRIAGE)

```bash
# 1. pull verified source for a target address (example shape; wire up explorer API)
#    cast etherscan-source <ADDR> --chain <CHAIN> -d targets/<name>/src

# 2. static first pass
slither targets/<name> --config-file tools/slither/slither.config.json \
  --checklist > targets/<name>/slither-report.md

# 3. custom pattern rules
semgrep --config tools/semgrep targets/<name>/src

# 4. hand the candidates to checklists/master-checklist.md
```

## Catalog integrity (run in CI)

```bash
pip install pyyaml
python3 tools/validate_catalog.py        # schema + path + cross-reference contract
python3 tools/gen_catalog_table.py        # regenerate README catalog table + counts
python3 tools/gen_catalog_table.py --check # CI: fail if README drifted from the catalog
```

- `validate_catalog.py` — the catalog's enforcement layer: every entry has the required
  fields; `status: coded` ⇔ a `poc`/`poc_cmd` that exists (and the inverse for `studied`);
  `doc`/`fork_poc` repo paths resolve; `class`/`checklist`/`semgrep` ids resolve to
  `docs/vuln-classes/`, `checklists/master-checklist.md`, and `tools/semgrep/`.
- `gen_catalog_table.py` — the README catalog table + counts are **generated** from
  `exploits.yaml`, never hand-maintained, so they can't drift.

## Subdirs
- `slither/` — config + notes on which detectors map to which checklist items
- `semgrep/` — custom rules, one per pattern we extract from a case study; every rule id
  referenced by a catalog entry's `semgrep:` field must exist here (CI-checked)
- `foundry-invariants/` — reusable invariant-test templates per vuln class
