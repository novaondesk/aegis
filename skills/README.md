# skills/ — Agent Skills

The suite packaged as loadable [Agent Skills](https://docs.claude.com) so any
Claude/agent can drive a review using our pattern library (modeled on `forefy/.context`).

## Install
Copy a skill directory into your agent's skills folder:
```bash
cp -r skills/smart-contract-bounty-review ~/.claude/skills/
# or per-project: <project>/.claude/skills/
```
The agent auto-discovers and invokes it by inference when you ask for a contract
review / bug hunt / PoC.

## Available skills
| Skill | Does |
|-------|------|
| `smart-contract-bounty-review` | Recon → triage → checklist review → PoC → report, using this repo's checklists, tools, and PoC workflow. EVM-mature; Solana/Move stubs as those checklists land. |

## Adding a skill
Create `skills/<name>/SKILL.md` with `name` + `description` frontmatter and the workflow.
Keep heavy reference material in the repo and link to it (progressive loading) rather
than inlining — token efficiency. See `../AGENTS.md`.
