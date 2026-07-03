#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { formatWfwResult, runWfw } from "./exec.js";
const projectRootSchema = z
    .string()
    .optional()
    .describe("Project directory (defaults to WFW_PROJECT_ROOT or process cwd)");
async function invokeWfw(args, projectRoot) {
    const result = await runWfw(args, projectRoot);
    const text = formatWfwResult(result);
    if (result.exitCode !== 0) {
        return {
            isError: true,
            content: [{ type: "text", text }],
        };
    }
    return {
        content: [{ type: "text", text }],
    };
}
const server = new McpServer({
    name: "wfw",
    version: "1.0.0",
});
server.tool("wfw_start", "Bootstrap team workspace and lease a treehouse worktree (wfw start)", {
    feature: z.string().describe("Feature name for treehouse --lease-holder"),
    project_root: projectRootSchema,
}, async ({ feature, project_root }) => invokeWfw(["start", feature], project_root));
server.tool("wfw_plan", "Open or queue a Lavish plan (wfw plan)", {
    prompt: z.string().optional().describe("Optional plan prompt for Lavish"),
    project_root: projectRootSchema,
}, async ({ prompt, project_root }) => {
    const args = prompt ? ["plan", prompt] : ["plan"];
    return invokeWfw(args, project_root);
});
server.tool("wfw_auto", "Run guarded gnhf in the current worktree (wfw auto)", {
    objective: z.string().describe("Objective passed to gnhf"),
    project_root: projectRootSchema,
}, async ({ objective, project_root }) => invokeWfw(["auto", objective], project_root));
server.tool("wfw_validate", "Push HEAD through no-mistakes pipeline (wfw validate)", {
    project_root: projectRootSchema,
}, async ({ project_root }) => invokeWfw(["validate"], project_root));
server.prompt("wfw-workflow", "Route a wfw subcommand through the correct MCP tool", {
    subcommand: z.string().describe("e.g. start, plan, auto, validate"),
    args: z.string().optional().describe("Arguments for the subcommand"),
}, async ({ subcommand, args }) => ({
    messages: [
        {
            role: "user",
            content: {
                type: "text",
                text: `Run workflowWrapper via MCP tools.\nSubcommand: ${subcommand}\nArgs: ${args ?? "(none)"}\n\nUse wfw_start, wfw_plan, wfw_auto, or wfw_validate. Always invoke tools rather than shelling out to gnhf directly.`,
            },
        },
    ],
}));
async function main() {
    const transport = new StdioServerTransport();
    await server.connect(transport);
}
main().catch((err) => {
    console.error(err);
    process.exit(1);
});
