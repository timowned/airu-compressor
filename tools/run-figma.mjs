import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";

const entryPoint = fileURLToPath(new URL("./figma-cli/src/index.js", import.meta.url));
const args = process.argv.slice(2);

// The upstream no-argument action patches/restarts Figma. Project usage shows help.
const child = spawn(process.execPath, [entryPoint, ...(args.length ? args : ["--help"])], {
  stdio: "inherit",
  env: { ...process.env, FIGMA_CLI_NO_UPDATE_CHECK: "1" },
});

child.on("error", (error) => {
  console.error(`Unable to start Figma CLI: ${error.message}`);
  process.exitCode = 1;
});

child.on("exit", (code, signal) => {
  if (signal) process.kill(process.pid, signal);
  else process.exitCode = code ?? 1;
});
