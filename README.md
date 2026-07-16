# workflowWrapper (wfw)

CLI that integrates **treehouse**, **lavish**, **gnhf**, and **no-mistakes** into one workflow.

Use the **terminal CLI** (`wfw`) or the **MCP server** (`wfw-mcp`) from any LLM client that supports Model Context Protocol.


## Why use wfw

**Primary value: one shared Lavish plan across parallel treehouse worktrees.**

When agents each run `wfw start <feature>` from the same app repo, treehouse leases separate worktrees.
Every worktree gets `lavish_artifact.html` wired to the same file: `shared_lavish_plan.html`.
Edits from any lease (or `wfw plan` from any worktree) are visible to every agent immediately.
```
  One laptop, one app repo
  ├── Agent/session A  →  treehouse lease "auth"
  ├── Agent/session B  →  treehouse lease "api"
  └── Both read/write the same
  shared_lavish_plan.html instantly
```
Nothing from the plan enters git - wfw adds the right `.git/info/exclude` entries on `wfw start`.

wfw also wraps the four tools behind a small command set, applies gnhf guardrails by default (12 iterations, 300k tokens), and skips the slow no-mistakes document step on `wfw validate` unless you override it.

## Why not just use the 4 tools separately

You can run treehouse, lavish, gnhf, and no-mistakes on their own.
wfw exists because the combined workflow has a lot of easy-to-get-wrong glue:

| If you DIY | What goes wrong | What wfw does |
|------------|-----------------|---------------|
| `treehouse get --lease` per person | Each person works in an isolated tree with no shared artifact | `wfw start` leases a worktree and wires the team plan in one step |
| Lavish on different HTML paths per worktree | Plans diverge; teammates paste screenshots into chat | One `shared_lavish_plan.html` at the app repo; every lease opens `lavish_artifact.html` pointing at it |
| Manual symlink + git exclude | Plan file gets committed, or symlinks break on re-lease | Creates/repairs symlinks, excludes plan + symlink from git automatically |
| `treehouse init` in the wrong directory | `treehouse.toml` under `my_team_workspace/` instead of repo root | Anchors config and shared workspace to the git repo root |
| Raw `gnhf` with no caps | Runaway token spend on hackathon tasks | `wfw auto` / `wfw gnhf` apply iteration and token guardrails |
| `git push origin` + manual PR + CI babysitting | Review and test happen after the branch is public | `wfw validate` pushes through the no-mistakes gate from the leased worktree |

**When to skip wfw:** you only need one tool in isolation (e.g. a single `treehouse` lease with no shared plan), or you already have your own orchestration.

## Install

Install the four underlying tools first, then workflow-wrapper.
`workflow-wrapper` is its own npm package - install it once per machine, not inside your app repo.

### 1. treehouse (worktree pool)

[treehouse](https://github.com/kunchenguid/treehouse) leases parallel git worktrees.

```bash
curl -fsSL https://kunchenguid.github.io/treehouse/install.sh | sh
# or: go install github.com/kunchenguid/treehouse@latest
```

### 2. lavish (interactive HTML plans)

[lavish-axi](https://github.com/kunchenguid/lavish-axi) renders interactive HTML plans for human review.
You need **Node.js 18+** and **npm**.

```bash
# optional global install
npm install -g lavish-axi

# wfw invokes this automatically:
npx -y lavish-axi <artifact.html>
```

### 3. gnhf (autonomous coding agent)

[gnhf](https://github.com/kunchenguid/gnhf) runs long agent loops against your repo.

```bash
npm install -g gnhf
```

### 4. no-mistakes (pre-push validation gate)

[no-mistakes](https://github.com/kunchenguid/no-mistakes) reviews, tests, lints, and opens a PR before code hits your real remote.

```bash
curl -fsSL https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh | sh
```

In **each app repo** you want to ship from (once per repo):

```bash
cd ~/CodingFun/my-app
no-mistakes init
# follow prompts; adds git remote "no-mistakes" and installs /no-mistakes skill
```

Requires **git**, **gh** (GitHub CLI), and at least one agent CLI (e.g. Claude Code, Antigravity `agy`, OpenCode).

### 5. workflow-wrapper (wfw)

Install globally from npm:

```bash
npm install -g workflow-wrapper
wfw setup
```

**Updates** - rerun install (fetches latest from GitHub):

```bash
npm install -g workflow-wrapper
wfw setup
```

**Developers** (optional local clone):

```bash
git clone https://github.com/Sea1vester/workflow-Wrapper.git ~/tools/workflow-wrapper
cd ~/tools/workflow-wrapper
npm install
npm link
```

Set `WFW_SKIP_POSTINSTALL=1` to skip skill/MCP refresh (e.g. CI).
`npm run install-skill` and `npm run install-mcp` still work for a manual refresh.

### Verify install

```bash
command -v treehouse gnhf wfw wfw-mcp git gh
node --version
```

## Use in your app repo

```bash
cd ~/CodingFun/my-app
wfw start my-feature    # interactive: lands in the leased worktree
wfw plan                # continue from there
```

Set `WFW_PROJECT_ROOT` if your MCP client's cwd is not the project directory.

## Commands

Concise reference.
Most commands after `start` run inside the leased worktree.

### Worktree

| Command | Purpose | Usage |
|---------|---------|-------|
| `wfw start <feature>` | Lease an isolated worktree; wire shared Lavish plan symlink | `wfw start auth-refactor` (enters shell when interactive) |
| `wfw start <feature> --path` | Print worktree path only | `cd "$(wfw start foo --path)"` |
| `wfw start <feature> --no-enter` | Lease but print `cd` hint only | For scripts / MCP |
| `wfw agent [feature]` | Open your agent CLI in a worktree | `wfw agent` or `wfw agent api --cli agy` |
| `wfw cleanup` | Drop merged, idle treehouse worktrees | `wfw cleanup` or `wfw cleanup --global` |

### Plan (Lavish)

`wfw plan "<prompt>"` queues text only - an agent must build the HTML artifact before the browser opens.

| Command | Purpose | Usage |
|---------|---------|-------|
| `wfw plan "<prompt>"` | Queue a plan prompt | `wfw plan "OAuth edge cases"` then build `lavish_artifact.html` |
| `wfw prompt "<text>"` | Same as `wfw plan "<prompt>"` | `wfw prompt "Add rate-limit section"` |
| `wfw plan` | Open plan in browser; listen for feedback | `wfw plan` (auto-resumes if agent harness interrupts) |
| `wfw plan --reply "<text>"` | Post agent reply; keep listening | `wfw plan --reply "Updated auth section"` |
| `wfw plan --open-only` | Open browser without listening | `wfw plan --open-only` |

### Build and ship

| Command | Purpose | Usage |
|---------|---------|-------|
| `wfw auto "<objective>"` | Run gnhf with guardrails in current worktree | `wfw auto "Implement the Lavish plan"` |
| `wfw validate` | Push through no-mistakes (review, tests, PR) | `wfw validate` |
| `wfw merge` | Merge feature branch into `main`/`master` locally | `wfw merge` (from feature worktree, after commit) |
| `wfw merge --abort` | Abort an in-progress merge on main | `wfw merge --abort` |

**Ship paths:** `wfw validate` for the no-mistakes PR gate; `wfw merge` for a direct local merge.
On merge conflict, fix files in the main worktree path wfw prints, commit, or run `wfw merge --abort`.
Merge parallel features one at a time; rebase other worktrees onto updated `main` before merging them.

### Setup and passthrough

| Command | Purpose | Usage |
|---------|---------|-------|
| `wfw setup` | Refresh `/wfw` skill and MCP config | `wfw setup` (after install or update) |
| `wfw treehouse <args>` | Raw treehouse CLI | `wfw treehouse status` |
| `wfw lavish <args>` | Raw lavish-axi CLI | `wfw lavish poll lavish_artifact.html` |
| `wfw gnhf <args>` | gnhf with wfw guardrails | `wfw gnhf "fix the tests"` |
| `wfw no-mistakes` | Same as `wfw validate` from a worktree | `wfw no-mistakes` |

**Worktree required** for `plan`, `auto`, `validate`, and `merge`.
Exception: `wfw agent <feature>` leases for you; `wfw start` runs from the app repo root.

### Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `WFW_GNHF_MAX_ITERATIONS` | `12` | gnhf iteration cap for `wfw auto` / `wfw gnhf` |
| `WFW_GNHF_MAX_TOKENS` | `300000` | gnhf token cap |
| `WFW_NO_MISTAKES_SKIP` | `document` | Skip no-mistakes document step on `wfw validate` (set empty to disable) |
| `WFW_VERBOSE` | `0` | Set to `1` to print symlink paths and gnhf guardrail lines |
| `WFW_PROJECT_ROOT` | cwd | Project directory for MCP tools |
| `WFW_AGENT_CLI` | auto-detect | Agent CLI for `wfw agent` (`claude`, `opencode`, `agy`, etc.) |
| `WFW_SKIP_WORKTREE_CLEANUP` | `0` | Set to `1` to skip `treehouse return` + `prune` after `wfw validate` |

## MCP tools (LLM-agnostic)

| Tool | Action |
|------|--------|
| `wfw_start` | `wfw start <feature>` |
| `wfw_plan` | `wfw plan [prompt]` (listens; use `agent_reply` after feedback) |
| `wfw_prompt` | `wfw prompt "<prompt>"` |
| `wfw_auto` | `wfw auto "<objective>"` |
| `wfw_agent` | `wfw agent [feature]` |
| `wfw_validate` | `wfw validate` |
| `wfw_merge` | `wfw merge` |
| `wfw_cleanup` | `wfw cleanup` |

MCP prompts (`wfw`, `wfw-start`, `wfw-plan`, `wfw-prompt`, `wfw-auto`, `wfw-validate`) route subcommands to the right tool.

Works with Cursor, Antigravity, Claude Desktop, OpenCode, and other MCP clients.

Gemini slash commands: `/wfw`, `/wfw:start`, `/wfw:plan`, `/wfw:auto`, `/wfw:validate` (via `npm run install-skill`).

## Layout (what wfw creates in your app repo)

```
<app-repo>/
  treehouse.toml
  my_team_workspace/
    shared_lavish_plan.html     # one live master plan, syncs in real time (git-ignored)

<leased-worktree-alice>/
  lavish_artifact.html          # symlink -> shared plan (git-ignored)
  ... your feature code ...

<leased-worktree-bob>/
  lavish_artifact.html          # same symlink target as alice
  ... bob's feature code ...
```

Agents work only inside their leased worktree after `wfw start`.
The parent `my_team_workspace/` path is an implementation detail they do not need to open.

## Verify the shared plan (developers)

Integration test for workflow-wrapper itself (requires `treehouse` on PATH):

```bash
cd ~/tools/workflow-wrapper
npm run test:integration
```

## Package layout

```
workflow-wrapper/
  bin/hack-wrap.sh           # wfw CLI
  bin/install-mcp.sh         # MCP client config
  bin/install-skill.sh       # slash commands for LLM CLIs
  mcp/                       # wfw-mcp server + prompts/gemini
  tests/integration/         # shared Lavish plan checks
  .no-mistakes.yaml          # test/lint commands for no-mistakes gate
```

## Typical end-user flow

This is the happy path for one teammate building and shipping a feature.
You never manage symlinks, shared plan paths, or tool wiring yourself - `wfw start` does that once.

```bash
# 1. From your app repo
cd ~/CodingFun/my-app
wfw start auth-refactor            # interactive: lands in the worktree
wfw plan "Map the OAuth login flow and edge cases"   # queues prompt; agent builds HTML
wfw plan                                            # open + listen for feedback
# after applying feedback:
wfw plan --reply "Updated auth section per your notes"

# 3. Build in this leased worktree (guardrailed gnhf)
wfw auto "Implement the approved Lavish plan"

# 4. Ship: no-mistakes PR or local merge
wfw validate
# or: wfw merge
```

**Parallel agents:** each person runs `wfw start <their-feature>` from the same app repo (each lands in their own worktree).
Everyone reads and edits the same live plan file without git commits or copy/paste between branches.

```bash
# Agent1
wfw start auth-refactor
wfw plan "OAuth provider matrix"

# Agent2 (same app repo, different lease)
wfw start api-hardening
wfw plan   # sees Agent1's updates immediately
```

After `wfw validate`, review and merge the PR no-mistakes opens.
`wfw validate` returns the treehouse lease and runs `treehouse prune` for worktrees already merged into the default branch.
Run `wfw cleanup` anytime to prune stale merged worktrees manually.
