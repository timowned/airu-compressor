# Native frontend integration

The implemented Auto Mode lives in `Packages/AiruUI`; the compression engine remains unchanged in `Packages/AiruCore`. `App/AiruApp.swift` owns the native NSWindow, NSHostingView, menu bar, document-open handling and application lifecycle. Manual mode displays only “Coming soon...”.

## Design source

[Airu Figma file](https://www.figma.com/design/9wDp8mCfIqvLw7f7FvlcWZ/Airu?node-id=4002-1390): UI page `0:1`, Auto Mode section `4012:4828`. Retrieved frames: initial `4002:1390`, drag `4003:1505`, processing `4004:1556`, uploaded `4010:3416`, completed `4010:2604`, row states `4010:2695`, format states `4012:3852`.

The local safe-mode Figma CLI inspected the hierarchy and exported reference frames. Figma MCP design contexts requested Swift/SwiftUI explicitly. Contexts, screenshots and downloaded original vector/bitmap assets are in `DesignReference/`. Runtime assets are offline Xcode asset catalogs, including the original drop mark, glow, folder icons, breadcrumb arrow and spinners. No screenshot is used as UI artwork.

The baseline window is 640×430 points, with a 58-point header, 20-point content insets, 50-point rows and SF system typography. `AiruStyle` centralizes the retrieved values. Top navigation and add controls use `GlassEffectContainer` and `.glassEffect(.regular.interactive(), in: Capsule())` on macOS 26+, as explicitly requested. Other controls retain the Figma styling. The native macOS traffic lights retain native behavior. Per-file controls appear on hover/keyboard focus, with equivalent context-menu and accessibility actions.

## Components and state

- `MainWindow`, drop zone and destination breadcrumb: mode routing, native file-URL drops, import, shared output controls and Airufy.
- `ImageListView` / image row: independent preparation/export status, measured sizes, progress, removal, per-file format/folder/export, errors, retry and Finder reveal.
- `FormatSelector`: Auto, AVIF, WebP, JPEG, PNG; JPEG disabled until the source is confirmed opaque. The fidelity mode remains Airy (SSIMULACRA2 target 90); Superlight is displayed as an unavailable “Coming soon...” option.
- `CompressionViewModel`: MainActor observable state, source-path deduplication, bounded background preparations, bounded cache exports, cancellation and generation tokens that discard obsolete results. Default concurrency is two. Individual errors do not stop other jobs.
- `ImageJobViewModel`: stable identity, source, analyzed metadata, selected format, verified result, status/progress, errors, destination override and exported URL.
- `ExportDestinationManager`: native NSOpenPanel, shared default, optional per-file override, saved bookmark and scoped URL lifetime. A stale bookmark falls back to Desktop. Development re-signing can invalidate scoped bookmarks; select the folder again if necessary.

## Backend boundary

`CompressionService` invokes the bundled `Contents/MacOS/airu-cli` through `CLIProcessBridge`, with an absolute executable path and argument array. Versioned, ordered NDJSON events are decoded into Codable models; diagnostic stderr stays separate. Pipe reading runs on a dedicated dispatch queue and UI mutations run on MainActor. No shell or log-string parsing is used. The bridge has deadlines, SIGINT cleanup, bounded forced termination and asynchronous process completion.

Import invokes only `analyze`. Rows with `.ready` and a nil result are analyzed and awaiting Airufy; only their original size is shown. Format changes invalidate the prior result and return to this waiting state without invoking encoders. Airufy (`exportAll`, or per-row `export`) queues `prepare`, then exports the verified result automatically. Newly added files remain waiting even during an active batch. Source contents are reanalyzed when compression starts. Valid deterministic cache entries are reused by Stage 1. Export invokes `export --key ... --destination ...`, validates source/cache identity and copies existing bytes without encoding. Already-optimized files retain their original bytes and have no invented score. The Stage 1 CLI two-step API is unchanged.

Security-scoped source/folder URLs stay retained across asynchronous work. Authorization failures invoke a native folder chooser and retry; other errors remain visible. The shipped configuration is a Developer-ID-style app with App Sandbox disabled. App Store sandboxing and helper-process scope validation remain separate distribution work; security-scoped URL usage alone does not establish sandbox support.

## Build and run

```sh
bash Scripts/build.sh
bash Scripts/test.sh
```

Open `dist/Airu.app` in Finder. Use the build script rather than running the raw Xcode target, which lacks distribution tools. The app bundles SwiftUI resources, CLI, eight native tools, 28 libraries and licenses. The current pinned arm64 toolchain requires macOS 27+. No Homebrew, Node or Python is needed by end users. Developer ID signing/notarization requires your credentials.

For a reviewable local launch, the GUI executable also accepts `--import PATH...` and `--destination FOLDER`; these still use real preparation and export services. They do not inject fabricated states. GUI tests use the same service with an isolated cache and temporary export directories.

Keyboard: ⌘O add images, ⌘S export ready files, ⇧⌘E choose the shared folder, Tab focus, Return export the focused row, Delete remove it. Native Edit and Window menus preserve standard macOS interactions.

## Verification

The core suite, frontend integration suite and black-box packaged CLI checks use real photographic, alpha, orientation, P3-profile and tiny-image fixtures. Frontend cases cover measured preparation/export, per-file formats, transparency/JPEG exclusion, active/queued removal, queued cancellation, Unicode and duplicate imports, unchanged results, rapid format changes/cache reuse, isolated errors, missing CLI, unique batch names, source invalidation and bookmark round trips. Logs: `Tests/stage2-all-tests.log`, `Tests/stage2-frontend-tests.log`, `Tests/stage2-build.log`.

Native application checks exercised the import picker, multi-selection, continued import, real processing percentages, per-file context actions, format changes, JPEG exclusion, active removal, custom-folder selection, Airufy, completed state and window zoom/resize. The actual JPEG export in `Tests/UIExports/photo-comp.avif` is 81,843 bytes, from a 113,946-byte source, with Stage 1 SSIMULACRA2 score 90.244169. Screenshots of empty, processing and completed states are in `Tests/Screenshots/`. Visual iteration corrected the title-bar inset, menu placement, native-control layout and asset sizing.

Native file-URL drag-and-drop is implemented using SwiftUI `onDrop` and `NSItemProvider`. Automated cross-window Finder drag gestures did not deliver a drop through the computer-use driver, so that gesture has not been independently confirmed by automation. Picker imports and the full real processing/export path were confirmed. A hands-on Finder drop remains a final UI acceptance check.

## File scrolling update

The added Figma “Scrolling” frame `4012:4829` and gradient `4012:5050` define the overflow treatment. `ImageListView` uses the downloaded 606×37 gradient asset above and below its native SwiftUI scroll content, mirrors it at the bottom, and only shows each fade when content remains in that direction. The footer remains fixed. A five-point gray draggable thumb tracks the actual scroll position and visible-content ratio. Short lists or larger windows hide the fades and thumb when all files fit.

`bash Scripts/build.sh` passes; see `Tests/scrolling-build.log`. Native verification used ten actual JPEG/PNG imports from the existing real fixtures. Wheel scrolling, top/middle/bottom fade behavior, thumb dragging and window resizing were visually checked. Screenshots: `Tests/Screenshots/auto-scrolling-middle.png`, `auto-scrolling-top.png`, `auto-scrolling-bottom.png`. The original downloaded gradient is bundled offline in `ScrollFade.imageset`; the Figma reference contexts are saved in `DesignReference/scrolling.tsx` and `scroll-gradient.tsx`.

## Drop-area background and motion

The app background and idle drop surface are solid #151515. The original Figma glow raster appears only while a file is dragged over the drop area, fades in/out over 400 ms, and stays clipped inside its rounded border. A 30% additive pass brightens the glow texture, whose base view opacity is already 100%. The header and window edges remain solid. The empty drop surface accepts drag events within its own bounds; dragging over outer padding does not activate it. The populated list uses the same drag feedback. Manual remains unavailable.

The glow drifts on independent 70- and 95-second paths during the drag; Reduce Motion keeps the texture static. Its TimelineView is removed when drag feedback ends. The icon, prompt and input targets stay fixed. Release packaging and deep/strict signature verification pass (`Tests/drop-background-build.log`). Live drag verification remains limited by the native automation timeout described below. Earlier first-screen screenshots show the superseded always-on background glow.

## Exact format dropdown

The dropdown now follows Figma node `4012:4813`: 260×148 panel, 10-point padding, 9-point outer radius, 1-point #272727 border, #1e1e1e background, 35-point choices with 6-point selected corners, and 13-point labels. JPEG, AVIF, WebP and PNG share one row; Airy and Superlight share the mode row. Airy remains the verified fidelity profile; Superlight is disabled until its behavior is specified. Auto remains the default and can be restored using the control’s “Use Auto format” context action. JPEG remains disabled for transparency.

A borderless native NSPanel opens 10 points above the selector, aligned to its leading edge, without a system popover arrow or extra system padding. It closes on selection, Escape, outside click, application deactivation, parent movement/resizing, or removal of its anchor. Per-file controls remain expanded while their menu is open. The footer’s “Compress to” label explicitly uses 13-point regular system text. Reference: `DesignReference/dropdown.tsx`. Build log: `Tests/dropdown-build.log`.

Dropdown validation: release packaging and deep/strict signature verification pass. All 13 frontend regression tests pass in 31.450 seconds with real encoders. Native preview confirmed the panel geometry, JPEG selection with an actual measured result, and Escape dismissal during implementation. The final interaction pass was interrupted by computer-use timeouts affecting both Airu and macOS Dock; a fresh automation session also timed out. Airu’s one-second process sample shows the main event loop idle rather than a busy compression/UI stack (`Tests/dropdown-sample.txt`). Final visual/dismissal verification remains limited by that automation failure.

## File-row hover motion

Row actions now use a 280 ms smooth slide/fade: removal enters from the leading edge and the grouped format/folder/export controls enter from the trailing edge, reversing on exit. Filename and size layout changes animate with the same transition. Horizontal motion extends beyond the row and list inset up to the window edge; vertical scroll content stays contained between header and footer. An open format menu keeps its actions visible. Reduce Motion uses a short opacity-only transition with immediate layout changes. Release packaging and signature verification pass (`Tests/hover-build.log`); live visual verification remains blocked by the native automation service timeout. Restart the running application to load the rebuilt executable.

The transition also tracks action visibility independently of hover/focus, so starting or finishing export while the pointer stays over a row animates the controls instead of abruptly removing or inserting them. Release packaging and deep/strict signature verification pass after this correction (`Tests/action-animation-build.log`). Live visual verification remains limited by the automation timeout described above.

## Airufy starts compression

Verified the click-to-compress workflow with 16 real frontend integration tests (36.340 seconds, zero failures). Import and format selection leave the candidate cache and export directory untouched. Coverage includes measured output sizes, SSIMULACRA2 ≥ 90, batch export, transparency, orientation, custom destinations, cancellation, cache reuse, current source contents, files added during compression, and cancellation after a format change. A focused follow-up also passed for Airufy enablement with invalid imports and completed files. Release packaging and deep/strict signature verification pass. Live UI interaction remains unverified because of the native automation timeout noted above.
