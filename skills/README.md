# skills/ — Agent Skills

Aegis packaged as a loadable [Agent Skill](https://docs.claude.com) so any Claude/agent
can drive a review using the exploit catalog — sweep a target against every known
exploit, then prove the hits with a PoC.

## Install
Copy the skill directory into your agent's skills folder:
```bash
cp -r skills/aegis-audit ~/.claude/skills/
# or per-project: <project>/.claude/skills/
```
The agent auto-discovers and invokes it by inference when you ask for a contract
review / "evaluate this against known exploits" / bug hunt / PoC.

> The skill reads `catalog/exploits.yaml`, `checklists/`, `docs/`, and `tools/` by
> relative path, so run it from a checkout of this repo (or copy those alongside it).

## Available skills
| Skill | Does |
|-------|------|
| `aegis-audit` | RECON → **catalog sweep** (target vs. every studied exploit) → checklist review → PoC → report. EVM-mature; Solana/Move entries are `studied` (catalog + doc) until their PoCs land. |

## Adding a skill
Create `skills/<name>/SKILL.md` with `name` + `description` frontmatter and the workflow.
Keep heavy reference material in the repo (the catalog, checklists, case studies) and
link to it (progressive loading) rather than inlining — token efficiency. See
[`../catalog/README.md`](../catalog/README.md) and [`../AGENTS.md`](../AGENTS.md).
