# workflowWrapper (wfw)

Hackathon CLI that integrates **treehouse**, **lavish**, **gnhf**, and **no-mistakes**.

Use the **terminal CLI** (`wfw`) or the **MCP server** (`wfw-mcp`) from any LLM client that supports Model Context Protocol.

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
my_team_workspace/
  shared_lavish_plan.html
  treehouse.toml
<leased-worktree>/
  lavish_artifact.html -> shared plan
```

## Package layout

```
workflow-wrapper/
  bin/hack-wrap.sh      # wfw CLI
  bin/install-mcp.sh    # MCP client config
  mcp/                  # wfw-mcp server (stdio)
```
