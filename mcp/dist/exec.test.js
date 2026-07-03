import assert from "node:assert/strict";
import test from "node:test";
import { formatWfwResult } from "./exec.js";
test("formatWfwResult combines stdout and stderr", () => {
    const text = formatWfwResult({
        stdout: "ok\n",
        stderr: "warn\n",
        exitCode: 0,
    });
    assert.match(text, /ok/);
    assert.match(text, /warn/);
});
test("formatWfwResult includes exit code on failure", () => {
    const text = formatWfwResult({
        stdout: "",
        stderr: "error",
        exitCode: 1,
    });
    assert.match(text, /exited with code 1/);
});
