#!/usr/bin/env python3
"""Generate the catalog table + counts from catalog/exploits.yaml.

No page should hand-maintain catalog numbers — they drift. This script rewrites the
blocks between the GENERATED markers, from the catalog (the single source of truth), in:
  - README.md            (the exploit table + counts)
  - docs/the-catalog.md  (the numbered detector table + heading, for the docs site)
  - docs/index.md        (the catalog count cell)
CI runs --check to fail on drift in any of them.

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
DOCS_CATALOG = ROOT / "docs" / "the-catalog.md"
DOCS_INDEX = ROOT / "docs" / "index.md"
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


def render_docs(entries):
    """The numbered detector table for the docs site (the-catalog.md) + index count cell."""
    coded = sum(1 for e in entries if e["status"] == "coded")

    heading = f"## All {len(entries)} detectors"

    rows = ["| # | Detector (`id`) | Class | Chains | Status |", "|---|---|---|---|---|"]
    for i, e in enumerate(entries, 1):
        eid = e["id"]
        # only coded entries have a PoC section to anchor-link to in pocs.md
        idcell = f"[`{eid}`](pocs#{eid})" if e["status"] == "coded" else f"`{eid}`"
        cls = "/".join(e.get("class") or [])
        chains = "/".join(e.get("chains") or [])
        rows.append(f"| {i} | {idcell} | {cls} | {chains} | {e['status']} |")

    index_count = f"{len(entries)} detectors ({coded} with runnable PoCs)"
    return heading, "\n".join(rows), index_count


def splice(text, marker, payload, where, inline=False):
    begin, end = f"<!-- BEGIN GENERATED: {marker} -->", f"<!-- END GENERATED: {marker} -->"
    pattern = re.compile(re.escape(begin) + r".*?" + re.escape(end), re.S)
    if not pattern.search(text):
        sys.exit(f"{where} is missing the {begin} / {end} markers")
    # inline form keeps everything on one line (e.g. inside a markdown table cell)
    joined = f"{begin}{payload}{end}" if inline else f"{begin}\n{payload}\n{end}"
    return pattern.sub(lambda _: joined, text)


def main():
    entries = yaml.safe_load(CATALOG.read_text(encoding="utf-8"))["exploits"]
    counts, table = render(entries)
    docs_heading, docs_table, index_count = render_docs(entries)

    # (path, [(marker, payload, inline), ...]) — every generated block across repo + docs site
    targets = [
        (README, [("catalog-counts", counts, False), ("catalog-table", table, False)]),
        (DOCS_CATALOG, [("docs-catalog-heading", docs_heading, False),
                        ("docs-catalog-table", docs_table, False)]),
        (DOCS_INDEX, [("docs-catalog-count", index_count, True)]),
    ]

    check = "--check" in sys.argv
    drift = False
    for path, blocks in targets:
        old = path.read_text(encoding="utf-8")
        new = old
        for marker, payload, inline in blocks:
            new = splice(new, marker, payload, path.name, inline=inline)
        if check:
            if new != old:
                print(f"{path.relative_to(ROOT)} is out of date — run: python3 tools/gen_catalog_table.py", file=sys.stderr)
                drift = True
        else:
            path.write_text(new, encoding="utf-8")

    if check:
        if drift:
            return 1
        print("README + docs site catalog tables/counts are in sync with catalog/exploits.yaml")
        return 0

    print(f"Regenerated README + docs site: {counts}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
