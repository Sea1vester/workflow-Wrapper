---
name: wfw
description: >-
  /wfw hackathon workflow: treehouse worktrees, Lavish plans, guarded gnhf, no-mistakes.
  Use when user invokes /wfw.
argument-hint: start <feature> | plan [prompt] | prompt <text> | auto "..." | validate | treehouse | lavish | gnhf | no-mistakes
---

# /wfw (LLM slash command only)

$ARGUMENTS

First token = subcommand; rest = args. Run matching shell via `wfw` (terminal CLI).

**Routes:** `start <feature>` | `plan` / `plan <prompt>` / `prompt <text>` | `auto "<obj>"` | `validate` | `treehouse …` | `lavish …` | `gnhf …` | `no-mistakes`

**Worktree required** for `auto`, `validate`, and open-only `plan`. Need `lavish_artifact.html` → else tell user `wfw start <feature>`.

**`prompt` / `plan <text>`:** like `/lavish` on team artifact (`lavish_artifact.html` or `my_team_workspace/shared_lavish_plan.html`). Write `.wfw/last-prompt.txt`, follow lavish skill (`~/.agents/skills/lavish/SKILL.md`), then `wfw lavish <artifact>` + poll.

**gnhf:** always via `wfw` with `--max-iterations 12 --max-tokens 300000` (env: `WFW_GNHF_MAX_*`).

**Install:** `npm link && npm run install-skill`
