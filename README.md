# workflowWrapper (wfw)

Hackathon CLI that integrates **treehouse**, **lavish**, **gnhf**, and **no-mistakes**.

## Install

```bash
npm link
npm run install-skill   # installs /wfw agent skill for Cursor
```

Prerequisites on PATH: `treehouse`, `gnhf`, `git` (with `no-mistakes` remote), `node`/`npm`.

## Detailed user workflow

End-to-end path for one teammate from install to shipped feature.
Terminal commands and LLM slash commands are shown together.

### Step 1 - Install (once per machine)

```bash
npm link
npm run install-skill
```

This gives you `wfw` in the terminal and `/wfw` in Cursor, OpenCode, Claude Code, or Gemini CLI.

### Step 2 - Lease a worktree (per feature)

```bash
wfw start auth-refactor
```

Creates `my_team_workspace/`, the shared Lavish plan, and a treehouse lease.
Your shell lands in the leased worktree with `lavish_artifact.html` symlinked to the team plan.

LLM: `/wfw start auth-refactor`

### Step 3 - Collaborative planning (Lavish)

```bash
wfw plan "Map OAuth login flow"
# or open the existing plan:
wfw plan
```

An agent builds or updates the shared HTML plan; teammates review and annotate in Lavish Editor.

LLM: `/wfw prompt Map OAuth login flow`

### Step 4 - Autonomous implementation (gnhf)

```bash
wfw auto "Implement the approved Lavish plan"
```

Runs gnhf from the worktree only, with guardrails: **12 iterations, 300k tokens** max.
Override via `WFW_GNHF_MAX_ITERATIONS` and `WFW_GNHF_MAX_TOKENS`.

LLM: `/wfw auto "Implement the approved Lavish plan"`

### Step 5 - Validate (no-mistakes)

```bash
wfw validate
```

Runs `git push no-mistakes HEAD`.
Blocked outside a feature worktree.

LLM: `/wfw validate`

### Parallel teammates

Each person runs `wfw start <their-feature>` for a separate treehouse lease.
All worktrees share one `shared_lavish_plan.html` for team alignment.
Use `wfw treehouse status` to inspect the pool.

## Terminal commands

```bash
wfw start my-feature          # workspace + treehouse lease + lavish symlink
wfw plan                      # open shared Lavish plan
wfw plan "Map the auth flow"  # queue prompt + open Lavish (/lavish-style)
wfw prompt "Map the auth flow"
wfw auto "Implement the plan" # gnhf with guardrails (12 iter, 300k tokens)
wfw validate                  # git push no-mistakes HEAD
```

## Passthrough (full upstream CLIs)

```bash
wfw treehouse status
wfw lavish poll lavish_artifact.html
wfw gnhf "objective"          # guardrails always applied
wfw no-mistakes validate
```

## Agent slash commands (LLM CLIs)

For **Cursor, OpenCode, Claude Code, Gemini CLI**, etc. - not the terminal `wfw` binary:

```
/wfw start my-feature
/wfw prompt Build the OAuth login flow
/wfw auto "Implement the approved plan"
/wfw validate
/wfw treehouse status
```

## Layout

```
my_team_workspace/
  shared_lavish_plan.html     # team Lavish plan
  treehouse.toml
<leased-worktree>/
  lavish_artifact.html        # symlink -> shared plan
```
