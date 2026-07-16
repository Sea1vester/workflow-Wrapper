function fill(template, args) {
    return template.replace(/\{\{(\w+)\}\}/g, (_, key) => args[key] ?? "");
}
const ROUTING = `The user invoked workflowWrapper (/wfw).

Request: {{args}}

Route to the correct wfw MCP tool or terminal command. Subcommands:
- start <feature> -> wfw_start
- agent [feature] -> wfw_agent
- plan [prompt] / prompt <text> -> wfw_plan or wfw_prompt
- auto "<objective>" -> wfw_auto
- validate -> wfw_validate
- cleanup -> wfw_cleanup

Primary value: one shared Lavish plan across parallel treehouse worktrees.
Each wfw start leases a worktree with lavish_artifact.html symlinked to
my_team_workspace/shared_lavish_plan.html at the git repo root.

Always invoke MCP tools (wfw_start, wfw_agent, wfw_plan, wfw_prompt, wfw_auto, wfw_validate, wfw_cleanup)
rather than reimplementing logic. Set project_root when the client cwd is not the repo.`;
export const WFW_PROMPTS = [
    {
        name: "wfw-workflow",
        description: "Deprecated alias for workflowWrapper help and routing (use wfw)",
        args: [{ name: "args", description: "Subcommand and arguments for wfw" }],
        template: (args) => fill(ROUTING, args),
    },
    {
        name: "wfw",
        description: "workflowWrapper help and routing (wfw)",
        args: [{ name: "args", description: "Subcommand and arguments for wfw" }],
        template: (args) => fill(ROUTING, args),
    },
    {
        name: "wfw-start",
        description: "Bootstrap shared Lavish plan, treehouse.toml, and lease worktree (wfw start)",
        args: [{ name: "feature", description: "Feature name for treehouse --lease-holder", required: true }],
        template: (args) => fill(`Run workflowWrapper start for feature: {{feature}}

Use the wfw_start MCP tool with feature="{{feature}}".

Creates treehouse.toml at the repo root (if missing), my_team_workspace/shared_lavish_plan.html,
and lavish_artifact.html as a symlink to that shared plan in the leased worktree.
Parallel teammates each get their own worktree but share the same plan file.

Report the worktree path and suggest wfw_plan next.`, args),
    },
    {
        name: "wfw-plan",
        description: "Open or build the shared Lavish plan (wfw plan)",
        args: [{ name: "prompt", description: "Optional plan prompt for Lavish" }],
        template: (args) => fill(`Run workflowWrapper plan.

User request: {{prompt}}

If the user provided text:
1. Use wfw_plan with prompt="{{prompt}}" (queues .wfw/last-prompt.txt only).
2. Build or update the team Lavish HTML artifact per the lavish skill.
3. Call wfw_plan again with no prompt to open lavish-axi and long-poll for feedback.

If no prompt text, use wfw_plan with no prompt to open and long-poll.

After poll feedback, apply changes to the HTML artifact, then call wfw_plan with agent_reply="<summary>".
That posts your reply in Lavish and polls again - do not end the turn without polling again during an active plan review.`, args),
    },
    {
        name: "wfw-prompt",
        description: "Queue a Lavish build prompt (wfw prompt)",
        args: [{ name: "prompt", description: "Plan prompt text", required: true }],
        template: (args) => fill(`Run workflowWrapper prompt with: {{prompt}}

Use the wfw_prompt MCP tool with prompt="{{prompt}}".

Queues .wfw/last-prompt.txt only. Build the Lavish HTML artifact, then call wfw_plan (no prompt) to open and poll.
After feedback, use wfw_plan with agent_reply to reply in the browser and poll again.`, args),
    },
    {
        name: "wfw-agent",
        description: "Lease a worktree and open the user's agent CLI (wfw agent)",
        args: [{ name: "feature", description: "Feature name for treehouse lease (optional inside a worktree)" }],
        template: (args) => fill(`Run workflowWrapper agent for feature: {{feature}}

Use wfw_agent with feature="{{feature}}" when not already inside a leased worktree.
From inside a worktree, wfw_agent with no feature opens the agent CLI there.

Detects claude, opencode, agy, gemini, cursor, or agent on PATH (override: WFW_AGENT_CLI).`, args),
    },
    {
        name: "wfw-auto",
        description: "Run guarded gnhf in the current worktree (wfw auto)",
        args: [{ name: "objective", description: "Objective passed to gnhf", required: true }],
        template: (args) => fill(`Run workflowWrapper auto with objective: {{objective}}

Use the wfw_auto MCP tool with objective="{{objective}}".

Guardrails: 12 iterations, 300k tokens max.`, args),
    },
    {
        name: "wfw-validate",
        description: "Push HEAD through no-mistakes validation (wfw validate)",
        template: () => `Run workflowWrapper validate.

Use the wfw_validate MCP tool.

After success, wfw returns the treehouse lease and prunes merged idle worktrees automatically.

Report the result.`,
    },
    {
        name: "wfw-cleanup",
        description: "Prune merged idle treehouse worktrees (wfw cleanup)",
        template: () => `Run workflowWrapper cleanup.

Use the wfw_cleanup MCP tool to run treehouse prune --yes in the current repo.`,
    },
];
