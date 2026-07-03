# workflowWrapper (wfw)

Hackathon CLI that integrates **treehouse**, **lavish**, **gnhf**, and **no-mistakes**.

## Install

```bash
npm link
npm run install-skill   # installs /wfw agent skill for Cursor
```

Prerequisites on PATH: `treehouse`, `gnhf`, `git` (with `no-mistakes` remote), `node`/`npm`.

## Terminal commands

```bash
wfw start my-feature          # workspace + treehouse lease + lavish symlink
wfw plan                      # open shared Lavish plan
wfw plan "Map the auth flow"  # queue prompt + open Lavish (/lavish-style)
wfw prompt "Map the auth flow"
wfw auto "Implement the plan" # gnhf with guardrails (12 iter, 30k tokens)
wfw validate                  # git push no-mistakes HEAD
```

## Passthrough (full upstream CLIs)

```bash
wfw treehouse status
wfw lavish poll lavish_artifact.html
wfw gnhf "objective"          # guardrails always applied
wfw no-mistakes validate
```

## Agent slash commands

After `npm run install-skill`:

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
