import assert from "node:assert/strict";
import test from "node:test";
import { WFW_PROMPTS } from "./prompts.js";
test("WFW_PROMPTS includes core workflow prompts", () => {
    const names = WFW_PROMPTS.map((p) => p.name);
    assert.deepEqual(names, [
        "wfw-workflow",
        "wfw",
        "wfw-start",
        "wfw-plan",
        "wfw-prompt",
        "wfw-auto",
        "wfw-validate",
    ]);
});
test("wfw-start template references wfw_start tool", () => {
    const start = WFW_PROMPTS.find((p) => p.name === "wfw-start");
    assert.ok(start);
    const text = start.template({ feature: "auth" });
    assert.match(text, /wfw_start/);
    assert.match(text, /auth/);
    assert.match(text, /shared_lavish_plan/);
});
test("wfw-workflow is a deprecated alias for wfw", () => {
    const legacy = WFW_PROMPTS.find((p) => p.name === "wfw-workflow");
    const current = WFW_PROMPTS.find((p) => p.name === "wfw");
    assert.ok(legacy);
    assert.ok(current);
    assert.equal(legacy.template({ args: "plan foo" }), current.template({ args: "plan foo" }));
});
