# Figma CLI in Airu

The downloaded `figma-cli-main` is vendored in `tools/figma-cli/`, using `figma-ds-cli` version 2.2.5. Its runtime, bridge plugin, optional bundled plugins, command references, examples, tests, and MIT license are retained. Claude-specific plugin metadata and session memory are not part of the integration.

It is a local development dependency. It is not imported by the Swift targets, and it does not select the macOS application architecture or Swift dependencies. Root `AGENTS.md` describes Airu’s tooling boundary; `tools/figma-cli/CODEX.md` adapts the CLI's original `CLAUDE.md` as a technical reference for Codex. No global npm installation or machine-wide Codex configuration is needed.

## Install and verify

Run from the Airu root:

```sh
npm ci
npm run figma -- --version
npm run figma
npm run figma:test
npm run figma:check
```

`npm run figma -- <command>` preserves CLI arguments and exit status. With no arguments it shows help, avoiding the upstream automatic desktop setup. The wrapper disables the upstream background npm update check, so this vendored version remains project-controlled.

`figma:test` runs the non-live upstream tests. It excludes `instantiate-roundtrip.test.js`, which otherwise probes a live connection and creates/removes a fixture page automatically. Live tests in `tests/live/` are also excluded. Do not run the vendor's unfiltered test command against a working design file.

## Live connection, when a Figma task is requested

The CLI controls a live Figma file; installation and help do not establish a connection. It does not need a Figma API token. Prefer the official-plugin mode:

```sh
npm run figma -- connect --safe
```

In Figma Desktop, import `tools/figma-cli/plugin/manifest.json` through **Plugins → Development → Import plugin from manifest**, then run **FigCli** in the intended design file. This first import is a Figma UI step. The project copy reports the manifest's actual location regardless of the shell's working directory.

Other supported modes:

- `connect --browser`: launches a dedicated Chromium browser profile for Figma; login and opening the target file happen there.
- Bare `connect`: patches and restarts Figma Desktop. Use this only when the user explicitly authorizes that behavior.

Pin the target when multiple files are open:

```sh
FIGMA_FILE="Airu" npm run figma -- eval 'figma.root.name'
```

Replace the example name with the actual target. Do not infer a file name or mutate whatever file happens to be active.

## Codex workflow

Read only the relevant reference sections. For implementation from Figma, extract or inspect the requested section, then map verified values into the existing Airu SwiftUI views, design tokens, and native components. CLI JSX creates Figma nodes; it is not production SwiftUI code.

```sh
npm run figma -- extract DESIGN.md --selection
npm run figma -- spec Button
npm run figma -- verify "123:456" --measure
```

These are usage examples for an authorized live session; a node ID and selection must come from the real target file. For design edits, use `render`/`render-batch`, reuse existing components and variables, preserve user nodes, and inspect verification images with Codex's image-viewing tool. Do not apply bundled shadcn tokens, dashboard blocks, or decorative defaults without a matching user brief.

`init-agent` is unnecessary. In particular, `init-agent --force` would replace the project's policy with upstream rules. The root policy intentionally has no upstream-managed rule block and is preserved by the CLI's normal `connect` rule-refresh behavior.

## Local integration changes

- Root npm scripts, a local file dependency, and the root lockfile integrate the tool.
- `tools/run-figma.mjs` supplies help by default and disables background update checks.
- `tools/test-figma.mjs` limits verification to non-live tests.
- `src/commands/setup.js` in the vendored CLI resolves the bridge manifest relative to its module, fixing the upstream assumption that the CLI is launched from its own directory.
- Root `AGENTS.md`, vendor `AGENTS.md`, and vendor `CODEX.md` supply Codex guidance. The original Claude guide is replaced by the adapted reference; historical upstream docs remain as third-party references.

The downloaded source folder is unchanged. To update the vendor later, review the new upstream snapshot, preserve the integration fix and guidance, update the root lockfile, and rerun both check commands.
