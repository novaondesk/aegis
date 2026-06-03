# skills/ — Agent Skills

Aegis packaged as a loadable [Agent Skill](https://docs.claude.com) so any Claude/agent
can drive a review using the exploit catalog — sweep a target against every known
exploit, then prove the hits with a PoC.

## Install

The skill reads `catalog/exploits.yaml`, `checklists/`, `docs/`, `poc/`, and `tools/`
by **repo-relative paths** (`../../…`). So it must be discovered **in place inside a
checkout** — register the repo's `skills/` dir, don't copy just the skill folder out
(a bare copy lands in `~/…/skills/aegis-audit/` with no repo around it, and the catalog
links resolve to nothing).

**Hermes** — add the repo's `skills/` dir to `skills.external_dirs` in `~/.hermes/config.yaml`:
```yaml
skills:
  external_dirs:
  - /path/to/aegis/skills
```
Hermes discovers `aegis-audit` in place (recursive `SKILL.md` scan), so `../../catalog`
etc. resolve. Verify with `hermes skills` / `skills_list`.

**Claude Code / Claude agents** — point the project at the repo or symlink it so the
skill keeps its repo siblings, e.g.:
```bash
ln -s /path/to/aegis/skills/aegis-audit ~/.claude/skills/aegis-audit   # symlink keeps ../../ intact
```
(A plain `cp -r` only works if you also copy `catalog/`, `checklists/`, `docs/`, `poc/`,
and `tools/` alongside it — prefer the symlink or a repo checkout.)

Either way the agent auto-discovers and invokes it by inference when you ask for a
contract review / "evaluate this against known exploits" / bug hunt / PoC.

> **Tooling:** `forge` (Foundry) drives EVM PoCs; `slither` + `semgrep` accelerate the
> automated TRIAGE pass if installed. The catalog sweep is reasoning-first and works
> without them — but non-EVM proofs and static-scan triage need their respective tools.

## Available skills
| Skill | Does |
|-------|------|
| `aegis-audit` | **Red team.** RECON & scope → **catalog sweep** (target vs. every studied exploit, using each entry's `root_cause` + `variant_queries`) → REVIEW engines (state-invariant + semantic-guard) for novel bugs → PoC → scored report. All 10 catalog entries are `coded`. |
| `aegis-defender` | **Blue team / protect.** Turns audit findings into minimal fixes **proven by a `Safe<X>` PoC** that defeats the same exploit, plus a deploy/upgrade **release-gate** (build integrity, storage-layout/upgrade safety, ownership handoff, signer opsec, config drift). |

The two compose: `aegis-audit` finds and proves the bug; `aegis-defender` proves the fix
and gates the release. Each skill keeps detail in its own `references/` (loaded on demand).

## Adding a skill
Create `skills/<name>/SKILL.md` with `name` + `description` frontmatter and the workflow.
Keep heavy reference material in the repo (the catalog, checklists, case studies) and
link to it (progressive loading) rather than inlining — token efficiency. See
[`../catalog/README.md`](../catalog/README.md) and [`../AGENTS.md`](../AGENTS.md).
