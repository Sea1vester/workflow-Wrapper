---
name: wfw
description: >-
  /wfw hackathon workflow: treehouse worktrees, Lavish plans, guarded gnhf, no-mistakes.
  Use when user invokes /wfw.
argument-hint: start <feature> | plan [prompt] | plan --reply "<text>" | prompt <text> | auto "..." | validate | treehouse | lavish | gnhf | no-mistakes
---

# /wfw (LLM slash command only)

$ARGUMENTS

First token = subcommand; rest = args. Run matching shell via `wfw` (terminal CLI).

**Primary value:** one shared Lavish plan across parallel worktrees.
`wfw start` wires the team plan into each leased worktree automatically.
Users `cd` into the printed worktree, then use `wfw plan`, `wfw auto`, and `wfw validate`.

**Routes:** `start <feature>` | `plan` / `plan <prompt>` / `plan --reply "<text>"` / `prompt <text>` | `auto "<obj>"` | `validate` | `treehouse …` | `lavish …` | `gnhf …` | `no-mistakes`

**Worktree required** for `auto`, `validate`, and `plan`/`prompt` with lavish-axi.
If missing, tell the user to run `wfw start <feature>` from the app repo and `cd` into the path it prints.

**`plan` workflow (two steps):**
1. **`wfw plan "<prompt>"` or `wfw prompt "<text>"`** - queues `.wfw/last-prompt.txt` only. Build/update the Lavish HTML artifact using the lavish skill (`~/.agents/skills/lavish/SKILL.md`), then continue.
2. **`wfw plan`** - opens lavish-axi on `lavish_artifact.html` and **long-polls** until the user sends feedback.
3. After applying poll feedback, **`wfw plan --reply "<summary>"`** - posts your reply in the browser and **polls again** for more feedback. Repeat step 3 until the user ends the Lavish session.

Never respond to the user in chat and end the turn while Lavish planning is active without running `wfw plan` or `wfw plan --reply` to keep polling. Use `wfw plan --open-only` to skip polling.

**gnhf:** always via `wfw` with `--max-iterations 12 --max-tokens 300000` (env: `WFW_GNHF_MAX_*`).

**Install:** `npm install -g github:Sea1vester/workflow-Wrapper` (updates: rerun the same command).

Slash commands differ per LLM CLI; terminal `wfw` works everywhere. See README.
