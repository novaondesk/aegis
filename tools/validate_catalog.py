#!/usr/bin/env python3
"""Validate catalog/exploits.yaml against the schema contract in catalog/README.md.

The catalog is the single source of truth, so its claims must be enforced:
  - every entry has the required fields, with a unique kebab-case id
  - status: coded  -> poc + poc_cmd set and the poc file exists
    status: studied -> poc/poc_cmd null/absent (catches the inverse mistake too)
  - doc paths exist; repo-local paths inside fork_poc exist
  - class ids resolve to docs/vuln-classes/README.md
  - checklist ids resolve to checklists/master-checklist.md
  - semgrep ids resolve to a rule in tools/semgrep/*.y*ml (or are explicitly n/a)

Run from the repo root:  python3 tools/validate_catalog.py
Exit code 0 = catalog is consistent; 1 = violations (printed one per line).
"""

import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "catalog" / "exploits.yaml"

# required on every entry regardless of lifecycle state
BASE_FIELDS = [
    "id", "name", "status", "class", "chains", "archetypes", "loss_usd",
    "date", "summary", "applies_when", "probes", "invariant", "doc",
    "checklist", "sources",
]
# additionally required once an entry is a real detector (studied/coded), not just
# a documented incident
DETECTOR_FIELDS = ["root_cause", "variant_queries", "detection", "semgrep"]
# lifecycle: documented (case study only) -> studied (detector, no PoC) -> coded (PoC)
VALID_STATUS = {"documented", "studied", "coded"}
VALID_CHAINS = {"evm", "solana", "sui-move", "aptos-move", "cosmwasm", "near", "ton", "tron", "polkadot", "multi"}
KEBAB = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
# repo dirs a fork_poc/poc path may point into
REPO_DIRS = ("sim/", "poc/", "ethernaut/", "dvd/", "tools/", "docs/")


def load_known_ids():
    """Collect the id universes the catalog cross-references."""
    classes = set()
    vc = (ROOT / "docs" / "vuln-classes" / "README.md").read_text(encoding="utf-8")
    classes |= set(re.findall(r"\bSC\d{2}\b", vc)) | set(re.findall(r"\bX\d{2}\b", vc))
    classes |= set(re.findall(r"\bSC-[a-z][a-z-]+\b", vc))  # named SC-<topic> classes

    # checklist ids live across master + the per-ecosystem checklists (Solana, Solodit, L2)
    checklist_ids = set()
    for f in (ROOT / "checklists").glob("*.md"):
        mc = f.read_text(encoding="utf-8")
        checklist_ids |= set(re.findall(r"\bSC\d{2}(?:-[A-Z0-9]+)*\b", mc))
        checklist_ids |= set(re.findall(r"\bX\d{2}(?:-[A-Z0-9]+)*\b", mc))
        checklist_ids |= set(re.findall(r"\bSC-[a-z][a-z0-9-]+\b", mc))  # SC-storage-layout(-02)
        checklist_ids |= set(re.findall(r"\bSOL-[A-Z0-9-]+\b", mc))      # Solana checklist ids

    semgrep_ids = set()
    for f in (ROOT / "tools" / "semgrep").glob("*.y*ml"):
        doc = yaml.safe_load(f.read_text(encoding="utf-8")) or {}
        for rule in doc.get("rules", []):
            if isinstance(rule, dict) and "id" in rule:
                semgrep_ids.add(rule["id"])
    return classes, checklist_ids, semgrep_ids


def repo_paths_in(text):
    """Extract repo-local paths embedded in a free-form fork_poc string."""
    out = []
    for tok in re.findall(r"[A-Za-z0-9_./-]+", text or ""):
        if tok.startswith(REPO_DIRS) and "/" in tok:
            out.append(tok.rstrip("."))
    return out


def main():
    errors = []
    data = yaml.safe_load(CATALOG.read_text(encoding="utf-8"))
    if "version" not in data:
        errors.append("catalog: missing top-level `version` field")
    entries = data.get("exploits") or []
    if not entries:
        errors.append("catalog: no `exploits` entries found")

    classes, checklist_ids, semgrep_ids = load_known_ids()
    seen = set()

    for e in entries:
        eid = e.get("id", "<missing-id>")
        where = f"[{eid}]"

        status = e.get("status")
        required = list(BASE_FIELDS)
        if status in ("studied", "coded"):
            required += DETECTOR_FIELDS
        for f in required:
            if f not in e or e[f] is None:
                errors.append(f"{where} missing required field `{f}`")

        if not KEBAB.match(eid):
            errors.append(f"{where} id is not kebab-case")
        if eid in seen:
            errors.append(f"{where} duplicate id")
        seen.add(eid)

        if status not in VALID_STATUS:
            errors.append(f"{where} status `{status}` not in {sorted(VALID_STATUS)}")
        poc, poc_cmd = e.get("poc"), e.get("poc_cmd")
        if status == "coded":
            if not poc or not poc_cmd:
                errors.append(f"{where} status=coded but poc/poc_cmd is null — either code the PoC or set status: studied")
            elif not (ROOT / poc).exists():
                errors.append(f"{where} poc path does not exist: {poc}")
        elif status in ("studied", "documented"):
            if poc or poc_cmd:
                errors.append(f"{where} status={status} but poc/poc_cmd is set — set status: coded if the PoC is real")

        for ch in e.get("chains") or []:
            if ch not in VALID_CHAINS:
                errors.append(f"{where} unknown chain `{ch}`")

        doc = e.get("doc")
        if doc and not (ROOT / doc).exists():
            errors.append(f"{where} doc path does not exist: {doc}")

        for p in repo_paths_in(e.get("fork_poc")):
            if not (ROOT / p).exists():
                errors.append(f"{where} fork_poc repo path does not exist: {p}")

        for c in e.get("class") or []:
            m = re.match(r"(SC\d{2}|X\d{2})", c)  # SC02-BRIDGE -> SC02; SC-storage-layout -> whole
            key = m.group(1) if m else c
            if key not in classes:
                errors.append(f"{where} class `{c}` does not resolve to docs/vuln-classes/README.md")

        for c in e.get("checklist") or []:
            # exact id, or a family prefix of concrete items (SC02-CB covers SC02-CB-1..3)
            if c not in checklist_ids and not any(k.startswith(c + "-") for k in checklist_ids):
                errors.append(f"{where} checklist id `{c}` not found in checklists/master-checklist.md")

        for s in e.get("semgrep") or []:
            if s == "n/a":
                continue
            if s not in semgrep_ids:
                errors.append(f"{where} semgrep rule `{s}` not found in tools/semgrep/")

    coded = sum(1 for e in entries if e.get("status") == "coded")
    studied = sum(1 for e in entries if e.get("status") == "studied")
    print(f"catalog: {len(entries)} entries ({coded} coded, {studied} studied)")

    if errors:
        for err in errors:
            print(f"ERROR {err}", file=sys.stderr)
        print(f"\n{len(errors)} violation(s)", file=sys.stderr)
        return 1
    print("OK — catalog is consistent")
    return 0


if __name__ == "__main__":
    sys.exit(main())
