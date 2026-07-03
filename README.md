# workflowWrapper (wfw)

Hackathon CLI that integrates **treehouse**, **lavish**, **gnhf**, and **no-mistakes**.

Use the **terminal CLI** (`wfw`) or the **MCP server** (`wfw-mcp`) from any LLM client that supports Model Context Protocol.

## Why use wfw

**Primary value: one shared Lavish plan across parallel worktrees.**

When teammates each run `wfw start <feature>` from the same app repo, treehouse leases separate worktrees, but every worktree gets `lavish_artifact.html` as a symlink to the same file: `my_team_workspace/shared_lavish_plan.html`. Edit the plan from any lease (or via `wfw plan` / `lavish-axi` on either symlink) and everyone sees the update immediately - no git commit, no copy/paste between branches. The symlink is listed in each worktree's `.git/info/exclude` so it never enters version control.

wfw also unifies treehouse, lavish, gnhf, and no-mistakes behind high-level commands, with gnhf guardrails (12 iterations, 300k tokens by default) as a secondary safety layer.

## Why not just use the 4 tools individually

Using treehouse, lavish, gnhf, and no-mistakes separately means manually coordinating leases, artifacts, and guardrails. You would need to wire up your own shared plan path and keep parallel worktrees in sync. wfw does that wiring once: shared plan + symlinks + git exclude on every `wfw start`.

## Verify the shared plan (integration test)

Requires `wfw` and `treehouse` on PATH (treehouse cannot run in all CI environments; the script skips when missing).

```bash
cd workflow-wrapper
npm run test:integration
```

Manual E2E from any git repo:

```bash
wfw start feature-a    # note worktree path A
wfw start feature-b    # note worktree path B (must differ)
readlink <A>/lavish_artifact.html   # same absolute path as B's symlink
echo test >> <A>/lavish_artifact.html
tail -1 <B>/lavish_artifact.html    # shows "test"
grep lavish_artifact.html <A>/.git/info/exclude
cd <A> && wfw plan                   # opens lavish-axi on lavish_artifact.html
```

## Install (once per machine)

`workflow-wrapper` is its own npm package - not your app repo.

```bash
git clone https://github.com/Sea1vester/workflow-Wrapper.git ~/tools/workflow-wrapper
cd ~/tools/workflow-wrapper
npm link
npm run install-mcp
```

This puts `wfw` and `wfw-mcp` on your PATH and registers the MCP server with supported clients.

Prerequisites on PATH: `treehouse`, `gnhf`, `git` (with `no-mistakes` remote), `node`/`npm`.

## Use in your app repo

```bash
cd ~/CodingFun/trainingDroid   # any git project
wfw start my-feature
```

Set `WFW_PROJECT_ROOT` if your MCP client's cwd is not the project directory.

## MCP tools (LLM-agnostic)

After `npm run install-mcp`, restart your LLM client. Available tools:

| Tool | Action |
|------|--------|
| `wfw_start` | `wfw start <feature>` |
| `wfw_plan` | `wfw plan [prompt]` |
| `wfw_auto` | `wfw auto "<objective>"` (guardrailed gnhf) |
| `wfw_validate` | `wfw validate` |

MCP prompt `wfw-workflow` routes subcommands to the right tool.

Works with any MCP-capable client (Cursor, Gemini CLI, Claude Desktop, OpenCode, etc.).

## Detailed user workflow

### Step 1 - Install

```bash
cd ~/tools/workflow-wrapper
npm link
npm run install-mcp
```

### Step 2 - Lease a worktree (from your app repo)

```bash
cd ~/CodingFun/trainingDroid
wfw start auth-refactor
```

Creates `my_team_workspace/`, shared Lavish plan, treehouse lease, and `lavish_artifact.html` symlink.

### Step 3 - Plan (Lavish)

```bash
wfw plan "Map OAuth login flow"
# or
wfw plan
```

### Step 4 - Build (gnhf, guardrailed)

```bash
wfw auto "Implement the approved Lavish plan"
```

12 iterations, 300k tokens max (`WFW_GNHF_MAX_ITERATIONS`, `WFW_GNHF_MAX_TOKENS`).

### Step 5 - Validate (no-mistakes)

```bash
wfw validate
```

### Parallel teammates

Each person runs `wfw start <their-feature>`. All worktrees share `shared_lavish_plan.html`.

## Terminal commands

```bash
wfw start my-feature
wfw plan "Map the auth flow"
wfw prompt "Map the auth flow"
wfw auto "Implement the plan"
wfw validate
wfw treehouse status
wfw lavish poll lavish_artifact.html
wfw gnhf "objective"
wfw no-mistakes validate
```

## Layout

```
<app-repo>/
  treehouse.toml
  my_team_workspace/
    shared_lavish_plan.html
<leased-worktree-A>/
  lavish_artifact.html -> <abs path>/my_team_workspace/shared_lavish_plan.html
<leased-worktree-B>/
  lavish_artifact.html -> same absolute path
```

## Package layout

```
workflow-wrapper/
  bin/hack-wrap.sh      # wfw CLI
  bin/install-mcp.sh    # MCP client config
  mcp/                  # wfw-mcp server (stdio)
```
