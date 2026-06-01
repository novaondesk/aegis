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

## Subdirs
- `slither/` — config + notes on which detectors map to which checklist items
- `semgrep/` — custom rules, one per pattern we extract from a case study
- `foundry-invariants/` — reusable invariant-test templates per vuln class
