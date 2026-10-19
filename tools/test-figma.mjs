import { spawn } from "node:child_process";
import { readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";

const cwd = fileURLToPath(new URL("./figma-cli/", import.meta.url));
const tests = readdirSync(new URL("./figma-cli/tests/", import.meta.url))
  .filter((name) => name.endsWith(".test.js") && name !== "instantiate-roundtrip.test.js")
  .sort()
  .map((name) => `tests/${name}`);

// The excluded roundtrip test modifies any connected Figma file automatically.
// Live checks belong to a separately authorized scratch-file session.
const child = spawn(process.execPath, ["--test", ...tests], {
  cwd,
  stdio: "inherit",
  env: { ...process.env, FIGMA_CLI_NO_UPDATE_CHECK: "1" },
});

child.on("error", (error) => {
  console.error(`Unable to run Figma CLI tests: ${error.message}`);
  process.exitCode = 1;
});

child.on("exit", (code, signal) => {
  if (signal) process.kill(process.pid, signal);
  else process.exitCode = code ?? 1;
});
