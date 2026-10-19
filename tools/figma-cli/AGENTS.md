# Vendored Figma CLI

This directory contains `figma-cli-main` from Downloads, package `figma-ds-cli` version 2.2.5, under its MIT license. It is development tooling, not Airu application code.

Follow root `AGENTS.md`. For Figma operations, read the relevant parts of `CODEX.md`, adapted from upstream `CLAUDE.md`. Generic examples do not override Airu's supplied designs or authorize live file edits, app patching, or global installation.

Preserve upstream source unless an integration issue requires a focused fix. Keep the local changes listed in root `Docs/figma-cli.md`. Run `npm run figma:test` from the root for non-live tests. The upstream `npm test` includes a roundtrip test that can create and remove nodes in a connected Figma file; do not run it as an ordinary project check.
