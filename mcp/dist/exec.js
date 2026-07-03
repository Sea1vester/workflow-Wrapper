import { spawn } from "node:child_process";
export function resolveProjectRoot(cwd) {
    return cwd ?? process.env.WFW_PROJECT_ROOT ?? process.cwd();
}
export function formatWfwResult(result) {
    const parts = [];
    if (result.stdout.trim()) {
        parts.push(result.stdout.trimEnd());
    }
    if (result.stderr.trim()) {
        parts.push(result.stderr.trimEnd());
    }
    if (result.exitCode !== 0) {
        parts.push(`[wfw exited with code ${result.exitCode}]`);
    }
    return parts.join("\n") || "(no output)";
}
export function runWfw(args, cwd) {
    const projectRoot = resolveProjectRoot(cwd);
    return new Promise((resolve, reject) => {
        const proc = spawn("wfw", args, {
            cwd: projectRoot,
            env: process.env,
            stdio: ["ignore", "pipe", "pipe"],
        });
        let stdout = "";
        let stderr = "";
        proc.stdout.setEncoding("utf8");
        proc.stderr.setEncoding("utf8");
        proc.stdout.on("data", (chunk) => {
            stdout += chunk;
        });
        proc.stderr.on("data", (chunk) => {
            stderr += chunk;
        });
        proc.on("error", reject);
        proc.on("close", (code) => {
            resolve({
                stdout,
                stderr,
                exitCode: code ?? 1,
            });
        });
    });
}
