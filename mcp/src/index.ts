#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { formatWfwResult, runWfw } from "./exec.js";
import { WFW_PROMPTS } from "./prompts.js";

const projectRootSchema = z
  .string()
  .optional()
  .describe("Project directory (defaults to WFW_PROJECT_ROOT or process cwd)");

async function invokeWfw(args: string[], projectRoot?: string) {
  const result = await runWfw(args, projectRoot);
  const text = formatWfwResult(result);
  if (result.exitCode !== 0) {
    return {
      isError: true as const,
      content: [{ type: "text" as const, text }],
    };
  }
  return {
    content: [{ type: "text" as const, text }],
  };
}

const server = new McpServer({
  name: "wfw",
  version: "1.1.0",
});

server.tool(
  "wfw_start",
  "Bootstrap team workspace, shared Lavish plan symlink, and lease a treehouse worktree (wfw start)",
  {
    feature: z.string().describe("Feature name for treehouse --lease-holder"),
    project_root: projectRootSchema,
  },
  async ({ feature, project_root }) => invokeWfw(["start", feature], project_root),
);

server.tool(
  "wfw_plan",
  "Open or queue a Lavish plan (wfw plan)",
  {
    prompt: z.string().optional().describe("Optional plan prompt for Lavish"),
    project_root: projectRootSchema,
  },
  async ({ prompt, project_root }) => {
    const args = prompt ? ["plan", prompt] : ["plan"];
    return invokeWfw(args, project_root);
  },
);

server.tool(
  "wfw_prompt",
  "Queue a Lavish build prompt and open lavish-axi (wfw prompt)",
  {
    prompt: z.string().describe("Plan prompt text for Lavish"),
    project_root: projectRootSchema,
  },
  async ({ prompt, project_root }) => invokeWfw(["prompt", prompt], project_root),
);

server.tool(
  "wfw_auto",
  "Run guarded gnhf in the current worktree (wfw auto)",
  {
    objective: z.string().describe("Objective passed to gnhf"),
    project_root: projectRootSchema,
  },
  async ({ objective, project_root }) => invokeWfw(["auto", objective], project_root),
);

server.tool(
  "wfw_validate",
  "Push HEAD through no-mistakes pipeline (wfw validate)",
  {
    project_root: projectRootSchema,
  },
  async ({ project_root }) => invokeWfw(["validate"], project_root),
);

for (const promptDef of WFW_PROMPTS) {
  const argSchemas: Record<string, z.ZodTypeAny> = {};
  for (const arg of promptDef.args ?? []) {
    argSchemas[arg.name] = arg.required
      ? z.string().describe(arg.description)
      : z.string().optional().describe(arg.description);
  }

  server.prompt(
    promptDef.name,
    promptDef.description,
    argSchemas,
    async (args) => ({
      messages: [
        {
          role: "user",
          content: {
            type: "text",
            text: promptDef.template(args as Record<string, string | undefined>),
          },
        },
      ],
    }),
  );
}

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
