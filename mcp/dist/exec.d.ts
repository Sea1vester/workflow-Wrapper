export interface WfwResult {
    stdout: string;
    stderr: string;
    exitCode: number;
}
export declare function resolveProjectRoot(cwd?: string): string;
export declare function formatWfwResult(result: WfwResult): string;
export declare function runWfw(args: string[], cwd?: string): Promise<WfwResult>;
