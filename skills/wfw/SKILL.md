---
name: wfw
description: >-
  Hackathon workflow orchestration integrating treehouse, lavish, gnhf, and
  no-mistakes. Use when the user invokes /wfw or wants the team workflow for
  worktrees, Lavish planning, guarded gnhf runs, or no-mistakes validation.
argument-hint: <command>, e.g. start my-feature | plan | prompt Build auth | auto "..." | validate | treehouse status
---

# workflowWrapper (/wfw)

workflowWrapper connects treehouse worktrees, Lavish planning, gnhf automation, and no-mistakes validation.
The CLI is `wfw`; this skill mirrors every terminal command as `/wfw`.

## Request

$ARGUMENTS

Parse the first token as the subcommand. Remaining tokens are arguments.

## Core problem solved

- Treehouse + Lavish integration via a shared `lavish_artifact.html` symlink per worktree
- Guardrailed gnhf so teammates cannot burst token usage accidentally
- Safe no-mistakes usage only from a leased feature worktree

## Command routing

| /wfw command | Terminal equivalent | Agent action |
|--------------|---------------------|--------------|
| `start <feature>` | `wfw start <feature>` | Run in shell; user must cd into leased worktree |
| `plan` | `wfw plan` | Open Lavish on `lavish_artifact.html` via `wfw lavish lavish_artifact.html` |
| `plan <prompt>` or `prompt <prompt>` | `wfw plan "<prompt>"` | **Lavish workflow** (see below) |
| `auto "<objective>"` | `wfw auto "<objective>"` | Run guarded gnhf in worktree |
| `validate` | `wfw validate` | Run `git push no-mistakes HEAD` in worktree |
| `treehouse ...` | `wfw treehouse ...` | Passthrough to treehouse |
| `lavish ...` | `wfw lavish ...` | Passthrough to `npx lavish-axi` |
| `gnhf ...` | `wfw gnhf ...` | Passthrough with guardrails (12 iter, 30k tokens) |
| `no-mistakes` | `wfw no-mistakes` | Safe validate push from worktree |

## /wfw prompt and /wfw plan <prompt> (Lavish integration)

When the user provides a prompt, behave like `/lavish` but target the team plan artifact:

1. Resolve artifact path:
   - In a feature worktree: `lavish_artifact.html` (symlink to shared plan)
   - Else: `my_team_workspace/shared_lavish_plan.html` or `.lavish/plan.html`
2. Write the prompt to `.wfw/last-prompt.txt`
3. Follow the lavish skill workflow: build or update the HTML artifact for the prompt
4. Run `wfw lavish <artifact>`
5. Run `wfw lavish poll <artifact>` and keep polling for feedback
6. Fix `layout_warnings` before involving the human

Read the lavish skill at `~/.agents/skills/lavish/SKILL.md` for HTML and poll rules.

## gnhf guardrails

Always pass through wfw (never call bare `gnhf` directly unless user insists):

- `--max-iterations 12` (override: `WFW_GNHF_MAX_ITERATIONS`)
- `--max-tokens 30000` (override: `WFW_GNHF_MAX_TOKENS`)

## Worktree requirement

`plan` (open only), `auto`, and `validate` require a feature worktree with `lavish_artifact.html`.
If missing, tell the user to run `/wfw start <feature-name>` first.

## Install

```bash
git clone <repo> && cd workflow-wrapper
npm link
npm run install-skill
```
