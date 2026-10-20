# AGENTS.md — AIRU

Engineering and workflow principles adapted from `maywand-main/AGENTS.md` for Airu.

# Instruction Precedence

Follow system and Codex developer instructions, then the user's explicit request. The policies below guide implementation within that scope; they do not authorize unrelated work or override a user's requested fidelity, verification, or deliverable. Communication preferences below apply where compatible with Codex's required progress updates and response formatting.

# Project Context

Airu is a native macOS image compressor built with Swift, SwiftUI, AppKit, Foundation, ImageIO, Core Graphics, and Swift Concurrency. The independent engine lives in `Packages/AiruCore`, the native CLI in `CLI`, the frontend in `Packages/AiruUI`, and the application lifecycle and bundle in `App`. Read `README.md` and `Docs/STAGE2.md` when a task needs architecture or workflow context.

Keep image analysis, encoder execution, perceptual optimization, cache management, export, batch scheduling, presentation state, visual components, and development tooling separate. The SwiftUI frontend uses the engine through the native CLI service. Keep Node/npm and Figma tooling outside Swift targets and the distributed app. Preserve existing ownership boundaries and use the supplied designs.

# Figma Tooling

The Figma CLI setup is copied from `maywand-main`, using the vendored `figma-ds-cli` 2.2.5 in `tools/figma-cli`. Read `Docs/figma-cli.md`, then only relevant sections of `tools/figma-cli/CODEX.md`. Invoke it with `npm run figma -- <command>`; no arguments show help. Adapt verified design values to native SwiftUI and preserve the supplied design. CLI JSX creates Figma nodes; it is not application code. Generic dashboard blocks or web presets do not define Airu's interface.

Installing tooling does not itself request a live Figma connection or design edits. For a requested live task, prefer `connect --safe`, with `tools/figma-cli/plugin/manifest.json`. Bare `connect` patches/restarts Figma Desktop and requires an explicit request for that behavior. Pin the intended file when multiple files are open and preserve user nodes. Do not run `init-agent --force` over project guidance.

# Checks

- `bash Scripts/test.sh`: native engine and CLI checks.
- `bash Scripts/build.sh`: release app packaging.
- `npm run figma:check`: Figma wrapper tests and non-live vendored CLI tests.

Use `npm run figma:test` instead of the vendor's unfiltered test command: the excluded `instantiate-roundtrip.test.js` and `tests/live` can mutate a connected Figma file. Node/npm are development dependencies only and must not be bundled with the compressor.

# Mission

Implement requested Airu changes with the highest value per credit spent.

Optimize for:
1. Clear user-facing improvement
2. Small, localized edits
3. Existing project patterns
4. Production-ready quality
5. Efficient context usage

Do not optimize for perfection. Optimize for useful delivery with minimal unnecessary work.

---

# Task Complexity

Before starting, classify the task as Level 1, Level 2, or Level 3.

## Level 1 — Surgical Task

Use for:
- copy changes
- CTA updates
- status or size-label text updates
- label changes
- simple spacing fixes
- changing one component
- removing or adding one small UI element

Rules:
- Find the relevant file/component quickly.
- Read only what is needed.
- Make the smallest possible diff.
- Do not refactor.
- Do not redesign nearby sections.
- Do not inspect unrelated files.

Expected behavior:
Finish quickly and report exactly what changed.

---

## Level 2 — Section Task

Use for:
- improving one native view
- changing a view layout
- adding one new view or state
- updating one interactive component
- fixing resizing behavior for one view
- improving a chart, funnel, timeline, or calculator

Rules:
- Inspect the target component and nearby styling.
- Reuse existing components, spacing, typography, colors, and patterns.
- Keep changes scoped to the selected section.
- Avoid touching global styles unless required.
- Do not modify unrelated sections.
- Run a targeted check if practical.

Expected behavior:
Improve the selected view without disturbing the rest of the application.

---

## Level 3 — System Task

Use for:
- full application interface redesign
- updating behavior across the application
- changing multiple sections
- architecture refactors
- window resizing or accessibility pass
- final UX/code review
- updating project docs or AGENTS.md

Rules:
- Read project context first.
- Inspect the affected architecture or view structure before editing.
- Create a short implementation plan before making changes.
- Work in focused passes.
- Preserve strong existing work.
- Refactor only when it improves maintainability or is required.
- Run the relevant build and checks if available.
- Review affected native window and interaction states if practical.

Expected behavior:
Think broadly, but still keep changes focused.

---

# Default Complexity Rule

If the user asks for a small change, assume Level 1.

If the user asks to improve one section, assume Level 2.

If the user asks to update the whole application, architecture, workflow, or multiple views, assume Level 3.

When unsure, choose the lower complexity level and keep the diff smaller.

---

# Repository Exploration

Repository exploration is expensive.

Always:
- Start with the file or section explicitly mentioned by the user.
- Use search only when the location is unknown.
- Read the minimum number of files needed to act confidently.
- Reuse information already discovered.
- Stop exploring once there is enough context to implement.
- Never inspect unrelated directories.

For Level 1:
- read only the target file/component when possible.

For Level 2:
- read the target component and nearby shared styles only if needed.

For Level 3:
- read project docs, affected architecture, and relevant shared components first.

---

# Decision Making

When multiple solutions are possible, choose the one that:

1. Changes the fewest files.
2. Preserves existing architecture.
3. Matches current coding patterns.
4. Is simple to maintain.
5. Improves clarity or the image-processing workflow.
6. Avoids unnecessary abstraction.

Prefer the first high-confidence solution.

Do not explore multiple implementation paths unless the user asks for options or the risk is meaningful.

---

# Editing Policy

Modify only what is necessary for the requested task.

Do not:
- refactor unrelated code
- rename components without reason
- move files
- reorganize folders
- rewrite existing patterns
- change formatting outside edited code
- improve nearby sections just because they could be better

If an existing component can be extended cleanly, extend it instead of creating a duplicate.

---

# Refactoring

Refactor only when:

- required to complete the task
- removing duplication introduced by the current task
- fixing a bug directly related to the task
- improving maintainability for a Level 3 task

Never perform proactive cleanup during Level 1 or Level 2 tasks.

---

# Dependencies

Do not install new packages unless they provide a clear and significant benefit for the requested feature.

Prefer:
- existing components
- existing utilities
- existing native animation APIs
- existing styling conventions

---

# Design Consistency

Preserve the existing design system.

Reuse:
- typography
- spacing
- colors
- components
- animations
- layout patterns
- visual rhythm

New UI should feel like it belongs in the existing product.

Use visuals only when they clarify the workflow, state, or result. Avoid decorative complexity that does not improve understanding.

Build for native macOS. Preserve basic resizing integrity at supported window sizes; do not add mobile-platform work without a request.

Avoid fixed pixel layouts that are hard to adapt later. Prefer flexible native layouts, reusable views, and appropriate window constraints.

---

# Airu Product and Processing Boundaries

Use the approved Airu requirements and the current native application behavior.

Do:
- keep compression independent of visual presentation
- use real encoder output, measured file sizes, and SSIMULACRA2 verification
- keep all image processing offline using bundled tools
- preserve resolution, orientation, color appearance, and transparency
- keep metadata analysis separate from user-initiated compression
- start compression when the user clicks Airufy
- preserve completed jobs when adding files or changing shared settings
- reuse verified cached output for export
- preserve the supplied Figma design and existing native controls

Do not fabricate progress, compressed sizes, perceptual scores, or successful verification. Do not silently accept unverified lossy output, discard alpha, resize images, or overwrite originals. Do not introduce codecs, dependencies, modes, or product behavior without a task that needs them. Manual mode remains unavailable until requested.

# Scope Control

Do exactly what was requested.

For Level 1 and Level 2 tasks:
- do not make “nice to have” improvements
- do not change unrelated sections
- do not rewrite copy outside the requested area
- do not redesign the full application unless asked

If you notice unrelated issues, mention them in the final notes instead of fixing them.

---

# Verification

Match verification effort to task complexity.

Level 1:
- mentally verify the edit
- run a small check only if fast and relevant

Level 2:
- run a targeted native build or relevant test if reasonable
- check the affected section for layout issues
- check window resizing if layout changed

Level 3:
- run relevant native builds and tests if available
- review affected window and interaction states
- check consistency across changed sections

If verification is skipped, mention why briefly.

---

# Communication

Do not narrate implementation.

Do not announce obvious actions before doing them.

Ask questions only when missing information blocks implementation or significantly affects product behavior.

If the intent is clear, make a reasonable assumption and continue.

For Level 1 and Level 2 tasks, work silently and respond only after completion.

For Level 3 tasks, provide one short plan before editing, then continue without progress narration unless blocked.

---

# Communication Discipline

Minimize conversational output during implementation.

Do not narrate obvious steps such as:
- “I will update...”
- “I found...”
- “I am running...”
- “I will now edit...”
- “I am checking...”

Only communicate during the task when:
- a clarification is required to continue
- there is a blocker
- a risky assumption must be confirmed
- a Level 3 task requires a short plan before editing

For Level 1 and Level 2 tasks:
- do not provide progress updates
- do not explain each file search
- do not describe obvious edits before making them
- implement silently, then provide the final summary

For Level 3 tasks:
- provide one short plan before editing
- avoid further progress narration unless blocked

Final response should be concise and use this format:

## Changed Files

- list modified files

## Summary

- concise summary of changes

## Notes

- checks run
- blockers or manual review items

For very small Level 1 tasks, use an even shorter final response.

---

# Output

After completing a task, keep the response concise.

Use this format:

## Changed Files

- list modified files

## Summary

- what changed and why

## Notes

- checks run
- anything requiring manual review

For very small Level 1 tasks, the response may be shorter.

Keep final responses short.

Avoid explaining implementation details unless they are important for review.

Do not include:
- long reasoning
- step-by-step narration
- repeated summaries
- obvious confirmations

Prefer concise status over detailed commentary.

---

# Working Principle

Move the project closer to completion with the least necessary implementation cost.

Explore only when needed.

Edit only what matters.

Prefer simple, maintainable solutions.

Preserve the product’s existing direction.

Every change should improve clarity, the compression workflow, or implementation quality.

## Visual Task Budget

For a single visual component or native view:

- Inspect only the target component and directly related styles.
- Make one implementation pass.
- Run at most one native screenshot comparison.
- Make at most one visual correction pass.
- After the second pass, report remaining differences; continue any work required to complete the user's explicit scope.
- Never iterate until “pixel perfect” or “minimal difference”.
- Do not check other platforms unless explicitly requested.
- Do not add animation unless explicitly requested.
- Do not create or update QA Markdown files unless explicitly requested.
- Do not run full-application visual QA for a component-level task.
- Use the smallest relevant native build or verification check.
- Do not modify unrelated files.
