#!/usr/bin/env python3
"""Generate the README catalog table + counts from catalog/exploits.yaml.

The README must never hand-maintain catalog numbers — they drift. This script
rewrites the blocks between the GENERATED markers in README.md from the catalog
(the single source of truth). CI runs --check to fail on drift.

Usage (from repo root):
  python3 tools/gen_catalog_table.py          # rewrite README.md in place
  python3 tools/gen_catalog_table.py --check  # exit 1 if README is out of date
"""

import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
README = ROOT / "README.md"
CATALOG = ROOT / "catalog" / "exploits.yaml"

CHAIN_NAMES = {
    "evm": "EVM", "solana": "Solana", "sui-move": "Sui/Move",
    "aptos-move": "Aptos/Move", "cosmwasm": "CosmWasm", "near": "NEAR",
    "ton": "TON", "tron": "TRON", "polkadot": "Polkadot", "multi": "multi",
}
# chains whose incidents are reproduced as Solidity models in poc/ (not native)
NON_EVM = {"solana", "sui-move", "aptos-move", "cosmwasm", "near", "ton", "tron"}


def fmt_loss(v):
    if v in (None, "recurring"):
        return "recurring"
    s = str(v).replace("_", "")
    # entries store either whole dollars (e.g. 14_400_000) or a millions shorthand (14.41)
    if "." in s:
        return f"${float(s):g}M"
    n = int(s)
    if n >= 1_000_000_000:
        return f"${n / 1_000_000_000:.4g}B"
    if n >= 1_000_000:
        return f"${n / 1_000_000:.3g}M"
    return f"${n / 1_000:.3g}k"


def render(entries):
    coded = [e for e in entries if e["status"] == "coded"]
    studied = [e for e in entries if e["status"] == "studied"]
    documented = [e for e in entries if e["status"] == "documented"]

    counts = (
        f"**{len(entries)} detectors — {len(coded)} with runnable PoCs (CI-enforced), "
        f"{len(studied)} studied (PoC pending), {len(documented)} documented (case study).**"
    )

    rows = ["| Exploit | Class | Chain | Loss | Status |", "|---|---|---|---|---|"]
    for e in entries:
        chains = e.get("chains") or []
        chain = "/".join(CHAIN_NAMES.get(c, c) for c in chains)
        # a coded PoC for a non-EVM incident is a Solidity model of the invariant
        if e["status"] == "coded" and chains and chains[0] in NON_EVM:
            chain += " *(EVM model)*"
        status = {
            "coded": "✅ coded PoC",
            "studied": "📚 studied",
            "documented": "📝 documented",
        }[e["status"]]
        cls = "/".join(e.get("class") or [])
        rows.append(f"| {e['name']} | {cls} | {chain} | {fmt_loss(e.get('loss_usd'))} | {status} |")
    return counts, "\n".join(rows)


def splice(text, marker, payload):
    begin, end = f"<!-- BEGIN GENERATED: {marker} -->", f"<!-- END GENERATED: {marker} -->"
    pattern = re.compile(re.escape(begin) + r".*?" + re.escape(end), re.S)
    if not pattern.search(text):
        sys.exit(f"README.md is missing the {begin} / {end} markers")
    return pattern.sub(f"{begin}\n{payload}\n{end}", text)


def main():
    entries = yaml.safe_load(CATALOG.read_text(encoding="utf-8"))["exploits"]
    counts, table = render(entries)

    old = README.read_text(encoding="utf-8")
    new = splice(old, "catalog-counts", counts)
    new = splice(new, "catalog-table", table)

    if "--check" in sys.argv:
        if new != old:
            print("README.md catalog table/counts are out of date — run:  python3 tools/gen_catalog_table.py", file=sys.stderr)
            return 1
        print("README.md catalog table/counts are in sync with catalog/exploits.yaml")
        return 0

    README.write_text(new, encoding="utf-8")
    print(f"README.md regenerated: {counts}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
