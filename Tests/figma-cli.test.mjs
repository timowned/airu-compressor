import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { ensureRules } from "../tools/figma-cli/src/lib/agent-rules.js";

const wrapper = fileURLToPath(new URL("../tools/run-figma.mjs", import.meta.url));

function run(...args) {
  return spawnSync(process.execPath, [wrapper, ...args], {
    encoding: "utf8",
    timeout: 8_000,
  });
}

test("project Figma command shows help instead of starting desktop setup", () => {
  const result = run();

  assert.equal(result.error, undefined);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Usage: figma-ds-cli/);
  assert.doesNotMatch(result.stdout, /Step 1\/3|Patching Figma Desktop|Starting Figma/);
});

test("project Figma command invokes the vendored version", () => {
  const result = run("--version");

  assert.equal(result.error, undefined);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout.trim(), "2.2.5");
});

test("project Figma command preserves failure status", () => {
  const result = run("missing-airu-command");

  assert.equal(result.error, undefined);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /unknown command/);
});

test("upstream connection rule refresh preserves the adapted Airu policy", (t) => {
  const directory = mkdtempSync(join(tmpdir(), "airu-agent-policy-"));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const policy = readFileSync(new URL("../AGENTS.md", import.meta.url), "utf8");
  const target = join(directory, "AGENTS.md");
  writeFileSync(target, policy);

  assert.deepEqual(ensureRules(directory, { home: "/nonexistent-home" }), []);
  assert.equal(readFileSync(target, "utf8"), policy);
});
