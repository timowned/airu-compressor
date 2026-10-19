# Airu

Airu is a native Swift macOS image compressor. The independent engine lives in `Packages/AiruCore`, the native CLI in `CLI`, and the minimal application shell in `App`. Stage 2 will implement the interface in SwiftUI using the supplied Figma design. Keep development tooling outside Swift targets and the distributed app.

## Figma tooling

The Figma CLI setup is copied from `maywand-main`, using the vendored `figma-ds-cli` 2.2.5 in `tools/figma-cli`. Read `Docs/figma-cli.md`, then only relevant sections of `tools/figma-cli/CODEX.md`. Invoke it with `npm run figma -- <command>`; no arguments show help. Adapt verified design values to native SwiftUI and preserve the supplied design. CLI JSX creates Figma nodes; it is not application code. Generic dashboard blocks or web presets do not define Airu's interface.

Installing tooling does not itself request a live Figma connection or design edits. For a requested live task, prefer `connect --safe`, with `tools/figma-cli/plugin/manifest.json`. Bare `connect` patches/restarts Figma Desktop and requires an explicit request for that behavior. Pin the intended file when multiple files are open and preserve user nodes. Do not run `init-agent --force` over project guidance.

## Checks

- `bash Scripts/test.sh`: native engine and CLI checks.
- `bash Scripts/build.sh`: release app packaging.
- `npm run figma:check`: Figma wrapper tests and non-live vendored CLI tests.

Use `npm run figma:test` instead of the vendor's unfiltered test command: the excluded `instantiate-roundtrip.test.js` and `tests/live` can mutate a connected Figma file. Node/npm are development dependencies only and must not be bundled with the compressor.
