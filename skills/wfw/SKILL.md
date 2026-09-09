---
name: wfw
description: >-
  /wfw hackathon workflow: treehouse worktrees, Lavish plans, autoresearch-style auto loop, no-mistakes.
  Use when user invokes /wfw.
argument-hint: start <feature> | agent [feature] | plan [prompt] | plan --reply "<text>" | prompt <text> | auto "..." | validate | cleanup | treehouse | lavish | no-mistakes
---

# /wfw (LLM slash command only)

$ARGUMENTS

First token = subcommand; rest = args. Run matching shell via `wfw` (terminal CLI).

**Primary value:** one shared Lavish plan across parallel worktrees.
`wfw start` wires the team plan into each leased worktree automatically.
Users `cd` into the printed worktree, then use `wfw plan`, `wfw auto`, and `wfw validate`.

**Routes:** `start <feature>` | `merge` / `merge --abort` | `agent [feature]` | `plan` / `plan <prompt>` / `plan --reply "<text>"` / `prompt <text>` | `auto "<obj>"` | `validate` | `cleanup` | `treehouse …` | `lavish …` | `no-mistakes`

**`start`:** leases a worktree and **enters it automatically** when run interactively in a terminal (`wfw start <feature>`). Creates git branch `feature/<name>` (treehouse pools use detached HEAD; wfw fixes that). Use `--path` for scripts or `--no-enter` to print `cd` only.

**`merge`:** from a feature worktree, merges your branch into `main`/`master` at the main worktree. On conflict, fix files in the main worktree (`cd` path printed), commit, or `wfw merge --abort`. Merge parallel features one at a time; rebase other worktrees onto updated main before merging them.

**`plan` listen loop:** `wfw plan` keeps listening for Lavish feedback and **auto-resumes** if the agent harness kills the poll. Build HTML before opening (`wfw plan` with no args on an empty artifact fails loudly).

**`agent`:** leases a treehouse worktree (like `start`) when given a feature name, then execs your agent CLI (`claude`, `opencode`, `agy`, `gemini`, `cursor`, etc.). From inside a worktree, `wfw agent` opens the CLI there. Override with `WFW_AGENT_CLI` or `wfw agent --cli <name>`.

**`cleanup`:** runs `treehouse prune --yes` to drop merged, idle worktrees. `wfw validate` also returns the current lease and prunes after a successful push (set `WFW_SKIP_WORKTREE_CLEANUP=1` to disable).

**Worktree required** for `auto`, `validate`, and `plan`/`prompt` with lavish-axi.
If missing, tell the user to run `wfw start <feature>` from the app repo and `cd` into the path it prints.

**`plan` workflow (two steps):**
1. **`wfw plan "<prompt>"` or `wfw prompt "<text>"`** - queues `.wfw/last-prompt.txt` only. Build/update the Lavish HTML artifact using the lavish skill (`~/.agents/skills/lavish/SKILL.md`), then continue.
2. **`wfw plan`** - opens lavish-axi on `lavish_artifact.html` and **long-polls** until the user sends feedback.
3. After applying poll feedback, **`wfw plan --reply "<summary>"`** - posts your reply in the browser and **polls again** for more feedback. Repeat step 3 until the user ends the Lavish session.

Never respond to the user in chat and end the turn while Lavish planning is active without running `wfw plan` or `wfw plan --reply` to keep listening. If poll was interrupted, run `wfw plan` again - wfw resumes automatically. Use `wfw plan --open-only` to skip listening.

**`auto`:** experiment loop in the current worktree. One agent change per iteration, then the repo test command. Failed iterations revert. Context accumulates in `.wfw/auto/context.md`. The loop closes when `.wfw/auto/DONE` exists and tests pass. Cap: `WFW_AUTO_MAX_ITERATIONS` (default 15). Do not invoke gnhf.

**Install:** `npm install -g github:Sea1vester/workflow-Wrapper` (updates: rerun the same command).

Slash commands differ per LLM CLI; terminal `wfw` works everywhere. See README.
