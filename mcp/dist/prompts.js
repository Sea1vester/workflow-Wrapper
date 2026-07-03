function fill(template, args) {
    return template.replace(/\{\{(\w+)\}\}/g, (_, key) => args[key] ?? "");
}
const ROUTING = `The user invoked workflowWrapper (/wfw).

Request: {{args}}

Route to the correct wfw MCP tool or terminal command. Subcommands:
- start <feature> -> wfw_start
- plan [prompt] / prompt <text> -> wfw_plan or wfw_prompt
- auto "<objective>" -> wfw_auto
- validate -> wfw_validate

Primary value: one shared Lavish plan across parallel treehouse worktrees.
Each wfw start leases a worktree with lavish_artifact.html symlinked to
my_team_workspace/shared_lavish_plan.html at the git repo root.

Always invoke MCP tools (wfw_start, wfw_plan, wfw_prompt, wfw_auto, wfw_validate)
rather than reimplementing logic. Set project_root when the client cwd is not the repo.`;
export const WFW_PROMPTS = [
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

If the user provided text, use wfw_plan with prompt="{{prompt}}".
Otherwise use wfw_plan with no prompt.

Follow the lavish workflow to build or update the team HTML artifact when a prompt was given.`, args),
    },
    {
        name: "wfw-prompt",
        description: "Queue a Lavish build prompt (wfw prompt)",
        args: [{ name: "prompt", description: "Plan prompt text", required: true }],
        template: (args) => fill(`Run workflowWrapper prompt with: {{prompt}}

Use the wfw_prompt MCP tool with prompt="{{prompt}}".

Writes .wfw/last-prompt.txt and opens lavish-axi on the shared plan artifact.`, args),
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

Report the result.`,
    },
];
