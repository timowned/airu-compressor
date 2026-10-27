# Airu

Native, offline image optimization with real AVIF, WebP, MozJPEG, OxiPNG, libimagequant (pngquant), and SSIMULACRA2 processes. The backend is independent of presentation. The native SwiftUI application includes Compress and Upscale workspaces using the Airu design system and Apple Liquid Glass controls. Upscale uses bundled Real-ESRGAN x4plus on the GPU, completely offline.

## Build and run

The checked-out workspace contains a development tool bundle and `dist/Airu.app`. Tools are never looked up through PATH. To rebuild from a clean checkout on Apple Silicon with Xcode/Swift 6 installed:

```sh
python3 Scripts/fetch-tools.py
python3 Scripts/bundle-tools.py --prefix .build/toolchain
python3 Scripts/bundle-upscaler.py
bash Scripts/build.sh
bash Scripts/test.sh
```

The fetch step downloads immutable, checksum-pinned archives; subsequent builds and all image processing are offline. Python is only a build dependency. End users receive the app, CLI, encoders, libraries, and licenses together and install no additional software.

For development only, `brew install libavif webp mozjpeg oxipng jpeg-xl pngquant` followed by `python3 Scripts/bundle-tools.py` bundles matching installed versions. The bundler refuses versions that do not match the lock.

```sh
swift build
.build/debug/airu analyze "image.jpg" --json
.build/debug/airu prepare "image.jpg" --tools Resources/Encoders --format auto
.build/debug/airu optimize "image.jpg" --tools Resources/Encoders --destination "/your/export/folder"
.build/debug/airu batch "one.jpg" "two.png" --tools Resources/Encoders --concurrency 2
```

Run the distributable CLI without a development tools path:

```sh
dist/Airu.app/Contents/MacOS/airu-cli optimize "image.jpg" --destination "/your/export/folder"
```

Step A is `prepare`; it returns verified, measured output sizes and a cache key. Step B is `export --key KEY`, which validates and copies the existing file. `optimize` is a convenience command combining both steps. `batch` prepares images concurrently and exports them only when `--destination` is supplied.

## AI agent workflow

Agents can use the native CLI directly without opening the app. Run `airu capabilities --json` for machine-readable commands, options, defaults, side effects and exit codes. Use `--request-id ID` to correlate NDJSON events, `doctor --json` for structured tool availability, and `analyze` → `prepare` → `export` for a measured, cache-backed workflow. Invalid command options are rejected before processing. See [the agent integration guide](Docs/AGENT_WORKFLOW.md) for a working subprocess example, batch/error handling, cancellation and export retry semantics. No automation server or additional runtime is required by Airu.

## Native application

Open `dist/Airu.app` in Finder after building. Click the drop zone or use ⌘O to select images. Import only analyzes and validates files, showing their original sizes. Drops show the glowing “Analyzing...” screen for at least three seconds while real analysis runs. Additional drops anywhere in the populated window add files at the top. Shared format changes and subsequent Airufy runs leave completed files unchanged. Select the format and destination, then click Airufy to start real compression, quality evaluation and export. Hover or keyboard-focus a row for removal and Show controls. Shared format and folder controls remain in the footer; per-file overrides are available in the context menu. Completed rows show measured compressed sizes and can reveal files in Finder. Format changes clear the previous result and wait for another Airufy click; valid cached candidates are reused when compression is requested. The format dropdown stays open for selection changes and closes on outside click. Airy uses lossless OxiPNG for PNG output and targets SSIMULACRA2 90 for other formats. Superlight uses libimagequant through pngquant followed by OxiPNG for PNG output, with an adaptive SSIMULACRA2 target of at least 80. The Upscale workspace keeps a separate file list and offers 2×/4× enhancement using the same export controls.

The UI launches the bundled `airu-cli` helper with typed arguments and decodes protocol-v1 NDJSON. It never implements compression itself. The distinct helper filename avoids a collision with the `Airu` GUI executable on case-insensitive macOS volumes. Xcode Build alone omits the helper and encoder bundle: use `bash Scripts/build.sh` to run the app.

## Behavior

- JPEG and PNG inputs are validated by their ImageIO content type and full decode. HEIC and WebP inputs use ImageIO when available. AVIF input/comparison decoding uses the bundled reference decoder.
- EXIF orientation is baked into a full-resolution processing raster. Width/height refer to visual dimensions, including orientation swaps. Output stays at original resolution unless Scale or Resolution is explicitly set.
- ICC profiles travel through PNG intermediates and explicit encoder metadata arguments. The evaluator composites in the reference RGB profile and uses SSIMULACRA2's color management to compare in its perceptual space. This preserves wide-gamut comparison information rather than clipping everything into 8-bit sRGB.
- Default acceptance is SSIMULACRA2 ≥90. Each codec has independent search bounds. Lossless fallback candidates and bounded binary probes are evaluated; the accepted candidate with the smallest **actual byte count** wins. This is the best among evaluated candidates, not a proof of a global optimum or an absolute guarantee of imperceptibility.
- If the optimization budget expires after a candidate has passed verification, that earlier verified candidate is retained. The interrupted candidate is discarded. Expiry before any acceptable candidate returns `timeout`; other evaluator failures remain errors.
- Auto evaluates AVIF/WebP and JPEG for opaque photographs, and the selected PNG pipeline plus appropriate alternatives for PNG input. Actual transparency excludes JPEG and alpha values must match exactly. Transparent candidates are evaluated against black and white; the lower score controls acceptance.
- Auto excludes codecs that cannot preserve the source dimensions. The bundled pipeline limits either dimension to 16,383 pixels for WebP, 32,768 for AVIF (including its reference decoder), and 65,500 for JPEG. Forced incompatible formats return `codecDimensionLimit`; the source is never resized automatically.
- The default budget is 24 candidates and 180 seconds per optimization, with at most two batch jobs and two encoder threads per job. Native raster operations and hashing are cancellation-checked between stages; an individual synchronous raster call cannot be interrupted midway. Encoder subprocesses have deadlines and cancellation cleanup.
- Failed encoders/evaluators produce explicit errors. There are no preset-only acceptances, synthetic quality scores, network services, or mock compression paths.
- Auto keeps a byte-identical original if no evaluated acceptable candidate is smaller. Its verification is `unchangedOriginal` and its score is absent. An explicitly forced format can be larger; sizes and negative savings remain accurate.
- SSIMULACRA2 requires both dimensions to be at least 8 pixels. Smaller images pass through unchanged in Auto or their original format, with no score. Forced conversion to another format returns `comparisonImageTooSmall`.
- The cache key includes SHA-256 of source contents, standardized source path, all optimization options, engine schema, and toolchain fingerprint. Cached files are hashed, decoded, and checked against their manifest before reuse/export. Changing source contents invalidates previous results.
- Exports default to `~/Desktop/Airu Compressed/`, use `name-comp.ext`, then `name-comp-2.ext`, and never overwrite originals. Directory locking, exclusive creation, Unicode normalization, and case folding handle collisions.
- When a full filename exceeds the destination filesystem's limit, export shortens the original stem while preserving complete Unicode characters, the `-comp` suffix, collision counter and extension. Full Unicode names are attempted first. Filename/path length errors return `filenameTooLong`, rather than incorrectly requesting folder authorization.
- New encodes retain the color profile and normalized orientation, but do not copy EXIF/GPS/XMP metadata. The lossless JPEG path preserves original metadata; unchanged copies preserve all original bytes.

## PNG modes

```sh
.build/debug/airu optimize image.png --format png --mode airy --tools Resources/Encoders --destination /tmp/airu
.build/debug/airu optimize image.png --format png --mode superlight --tools Resources/Encoders --destination /tmp/airu
```

Airy applies OxiPNG level 3 directly to an unrotated PNG, retaining pixel data, alpha, and color-description chunks. Other inputs/orientations use the normalized full-resolution raster. Decoded pixels must match exactly; quality is also measured with SSIMULACRA2.

Superlight first creates the lossless fallback, then adaptively searches pngquant's palette-quality scale, followed by OxiPNG. Its `--score` defaults to 80 and cannot be lower than 80. Scores and actual output sizes determine acceptance and selection; pngquant's own quality numbers are not SSIMULACRA2 scores. Source ICC/gamma interpretation is retained around palette quantization to avoid pngquant's default sRGB conversion. Transparent results must preserve alpha values exactly and pass comparisons on black and white. Palette probes that alter alpha are rejected. Some photographs exceed what 256 colors can represent at this threshold; these retain the verified lossless fallback. Auto always retains the original when no acceptable evaluated output is smaller.

`OptimizationOptions.pngMode` and CLI `--mode airy|superlight` select the pipeline explicitly; the native UI forwards its selected mode. Mode and quality options are included in the cache key. Existing cache manifests without the new mode field are invalidated and prepared again. All tools are bundled; users install no dependencies.

**Dependency licensing:** pngquant 3.0.3 includes libimagequant 4.2.2 and is offered under GPL-3.0-or-later with additional notices, or a commercial license. Its full COPYRIGHT/license text is bundled. Non-GPL/closed-source or App Store redistribution requires resolving the upstream commercial licensing terms; this implementation does not grant such a license. See [upstream licensing](https://pngquant.org/licensing.html) and [dependency details](Docs/DEPENDENCIES.md).

## Supported deployment and limits

The app icon uses Apple's complete bitmap macOS family: 16, 32, 128, 256 and 512 points, each at 1× and 2× (16–1024 pixels). macOS selects the appropriate representation for Dock, Finder, Open With menus, app grids, About and Cmd-Tab. The supplied logo retains its centered 80% artwork footprint and transparent padding; that footprint is Airu's optical sizing choice. `Scripts/build.sh` regenerates assets from `App/IconSource.png`, retains Xcode's standard `AppIcon.icns` with its 128pt logical canvas for system views and packages a separate full-resolution `AiruIcon.icns` for the running Dock icon. The Dock image also uses a 128pt logical size while retaining all ten bitmap representations. Build checks verify both the system icon geometry and the full family before signing. Verify a packaged app independently with `swift Scripts/generate-icon.swift --verify dist/Airu.app`. No separate status-bar icon is needed because Airu has no menu-bar status item.

The Swift package targets macOS 14+. **The current pinned binary distribution requires macOS 27.0+, Apple Silicon.** This is the actual minimum declared by the downloaded encoder/library Mach-O files and recorded in `Resources/Encoders/manifest.json` and the app Info.plist. Older OS compatibility requires a separately rebuilt and tested toolchain; it is not claimed here.

Stage 1 accepts SDR RGB/grayscale inputs up to 8 bits/channel and 80 million pixels. CMYK, higher bit depths, HDR gain maps, animation, and multi-frame sources return explicit unsupported errors to avoid silently damaging appearance. Resizing, alpha flattening, HDR conversion, and Manual compression controls are outside this implementation.

The local app uses ad hoc development signatures. Developer ID builds enable hardened runtime; signing/notarization require your Apple credentials, and `Scripts/notarize.sh` implements that final distribution step. This build has not been notarized or tested on another physical Mac. All non-system dylib references are relocated into the app and arm64/signature checks run during packaging. The permission helper presents NSOpenPanel and stores security-scoped bookmarks; the CLI reports `authorizationRequired` if its caller must choose a folder.

## Project layout

```text
Airu.xcodeproj/              Native macOS application
App/                        App lifecycle, native window and menu bar
Packages/AiruUI/             SwiftUI views, view models, CLI bridge, assets and tests
Packages/AiruCore/           Independent compression package
  Sources/AiruCore/          Analysis, tools, optimizer, cache, export, batch, Codable models
  Tests/AiruCoreTests/       Unit/integration tests and attributed real fixtures
CLI/                        Native CLI, NDJSON protocol, signal cancellation
Resources/Encoders/          Tool bundle, manifest and third-party licenses
Scripts/                    Locked dependency fetch, relocation, build, test, signing
DesignReference/            Retrieved Figma contexts, frames and original assets
Docs/                       Frontend integration, CLI protocol and dependency details
Tests/Screenshots/          Captures of the running native app
Tests/Output/               Verified end-to-end exports
dist/Airu.app/              Self-contained local development app
```

See [Stage 2 integration](Docs/STAGE2.md), [CLI protocol](Docs/CLI_PROTOCOL.md), [dependency interfaces](Docs/DEPENDENCIES.md), and [verification record](Docs/VERIFICATION.md).

## Figma development tooling

The project-local Figma CLI setup is copied from `maywand-main` (version 2.2.5), with its bridge plugin, references, safe wrapper, and non-live tests. Install with `npm ci`, run `npm run figma -- --version`, and verify with `npm run figma:check`. See [Figma CLI setup](Docs/figma-cli.md) for connection instructions. This tooling is separate from the native application and its distribution dependencies.

## Scale and Resolution

The format dropdown includes Scale (default 100%) and editable width/height. Commit a value with Return or by leaving the field. Percentage scaling uses each image’s oriented original dimensions; exact resolution applies the same aspect-fill crop to every pending image. The alignment button is enabled for custom resolution and opens a 3×3 picker (center by default). The icon highlights the selected edges or center; percentage scaling disables it. Different batch originals display the first pending image’s calculated dimensions. Setting 100% restores original dimensions and removes cropping. Completed files remain unchanged until reset.

The CLI supports `--scale 50` or `--width 2000 --height 2000` on prepare, optimize, and batch. These options are mutually exclusive. With exact resolution, `--alignment top-left|top|top-right|left|center|right|bottom-left|bottom|bottom-right` selects the crop anchor. Alignment participates in cache identity. Resizing uses Accelerate/vImage Lanczos-3 before encoding; SSIMULACRA2 compares against that resized reference. Options participate in cache identity and exported outputs are validated against the requested dimensions. Color profiles and alpha travel through the normalized PNG reference. Native intermediates use the existing 8-bit processing raster. Explicit upscaling is supported, subject to a 65500-pixel side / 100-megapixel output allocation bound. Scaling and cropping are fused into one proportional vImage transform, avoiding a potentially huge aspect-fill intermediate.

Auto reports `noSmallerResizedOutput` if no valid resized output is smaller than the source; it never silently restores the original dimensions. Select an explicit format to permit larger resized output. Resized targets smaller than 8 pixels on either axis return `comparisonImageTooSmall` because SSIMULACRA2 cannot verify them.

## Real-ESRGAN Upscale

Choose **Upscale**, add images, select 2× or 4× and an output format, then click **Airufy**. Import does metadata analysis only. Completed jobs stay unchanged when settings change; Reset All makes them editable again. Stop cancels the active workspace. Closing the app cancels both workspaces. Compression and upscale lists are independent, with a single neural preparation at a time.

`airu prepare photo.png --upscale 2 --format png --tools Resources/Encoders` creates a verified cache artifact; `optimize` also exports it, while `batch --upscale 4` uses the existing batch API. Upscale flags are exclusive with ordinary resize options. Outputs use `name-upscaled-2x.ext` or `name-upscaled-4x.ext` and the existing collision-safe export logic. Larger files are expected and their actual sizes are reported. Auto may select larger output for explicitly requested AI upscaling, while normal compression retains its no-larger-output rule.

The pinned official 20220424 ncnn/Vulkan universal release is checksum-verified, thinned to arm64 and bundled by `Scripts/bundle-upscaler.py`. The included photographic `realesrgan-x4plus` model infers 4× detail; 2× output is then resampled with Lanczos-3. The helper statically includes MoltenVK and uses the Apple GPU through Metal. It requires no external dylibs, Python, Homebrew or network during use. All runtime binaries/models are in `Resources/Upscaler` (generated by the build dependency script); licenses and archive provenance are retained there. Signing refreshes the model/helper manifest before signing the app. No scripts disable Gatekeeper.

EXIF orientation is applied first. Alpha is resampled separately from the neural RGB output, and the original RGB profile is restored. Processing follows the existing 8-bit raster pipeline. The 4× intermediate is limited to 100 megapixels. The selected model reconstructs detail and may invent features; it does not recover guaranteed original detail. SSIMULACRA2 verifies **encoding against the enhanced reference**, not the accuracy of reconstruction against the low-resolution source. Missing or damaged helpers/models and GPU failures are explicit errors; there is no interpolation-only fallback. AI progress stays at zero during the uninstrumented inference stage, then follows actual encoding/evaluation events rather than a simulated timer.
