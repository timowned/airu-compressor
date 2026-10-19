# Airu

Native, offline image optimization with real AVIF, WebP, MozJPEG, OxiPNG, and SSIMULACRA2 processes. The backend is independent of presentation. The native SwiftUI application implements Auto Mode from the Airu Figma file, with Apple Liquid Glass navigation controls. Manual mode displays “Coming soon...”.

## Build and run

The checked-out workspace contains a development tool bundle and `dist/Airu.app`. Tools are never looked up through PATH. To rebuild from a clean checkout on Apple Silicon with Xcode/Swift 6 installed:

```sh
python3 Scripts/fetch-tools.py
python3 Scripts/bundle-tools.py --prefix .build/toolchain
bash Scripts/build.sh
bash Scripts/test.sh
```

The fetch step downloads immutable, checksum-pinned archives; subsequent builds and all image processing are offline. Python is only a build dependency. End users receive the app, CLI, encoders, libraries, and licenses together and install no additional software.

For development only, `brew install libavif webp mozjpeg oxipng jpeg-xl` followed by `python3 Scripts/bundle-tools.py` bundles matching installed versions. The bundler refuses versions that do not match the lock.

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

## Native application

Open `dist/Airu.app` in Finder after building. Click the drop zone or use ⌘O to select images. Import only analyzes and validates files, showing their original sizes. Select the format and destination, then click Airufy to start real compression, quality evaluation and export. Hover or keyboard-focus a row for removal, per-file format, folder and Airufy controls; the context menu offers the same actions. Completed rows show measured compressed sizes and can reveal files in Finder. Format changes clear the previous result and wait for another Airufy click; valid cached candidates are reused when compression is requested. Manual mode remains “Coming soon...”.

The UI launches the bundled `airu-cli` helper with typed arguments and decodes protocol-v1 NDJSON. It never implements compression itself. The distinct helper filename avoids a collision with the `Airu` GUI executable on case-insensitive macOS volumes. Xcode Build alone omits the helper and encoder bundle: use `bash Scripts/build.sh` to run the app.

## Behavior

- JPEG and PNG inputs are validated by their ImageIO content type and full decode. HEIC and WebP inputs use ImageIO when available. AVIF input/comparison decoding uses the bundled reference decoder.
- EXIF orientation is baked into a full-resolution processing raster. Width/height refer to visual dimensions, including orientation swaps. No output is resized.
- ICC profiles travel through PNG intermediates and explicit encoder metadata arguments. The evaluator composites in the reference RGB profile and uses SSIMULACRA2's color management to compare in its perceptual space. This preserves wide-gamut comparison information rather than clipping everything into 8-bit sRGB.
- Default acceptance is SSIMULACRA2 ≥90. Each codec has independent search bounds. Lossless fallback candidates and bounded binary probes are evaluated; the accepted candidate with the smallest **actual byte count** wins. This is the best among evaluated candidates, not a proof of a global optimum or an absolute guarantee of imperceptibility.
- Auto evaluates AVIF/WebP and JPEG for opaque photographs, and lossless PNG plus appropriate alternatives for PNG input. Alpha excludes JPEG and must match exactly. Transparent candidates are evaluated against black and white; the lower score controls acceptance.
- The default budget is 24 candidates and 180 seconds per optimization, with at most two batch jobs and two encoder threads per job. Native raster operations and hashing are cancellation-checked between stages; an individual synchronous raster call cannot be interrupted midway. Encoder subprocesses have deadlines and cancellation cleanup.
- Failed encoders/evaluators produce explicit errors. There are no preset-only acceptances, synthetic quality scores, network services, or mock compression paths.
- Auto keeps a byte-identical original if no evaluated acceptable candidate is smaller. Its verification is `unchangedOriginal` and its score is absent. An explicitly forced format can be larger; sizes and negative savings remain accurate.
- SSIMULACRA2 requires both dimensions to be at least 8 pixels. Smaller images pass through unchanged in Auto or their original format, with no score. Forced conversion to another format returns `comparisonImageTooSmall`.
- The cache key includes SHA-256 of source contents, standardized source path, all optimization options, engine schema, and toolchain fingerprint. Cached files are hashed, decoded, and checked against their manifest before reuse/export. Changing source contents invalidates previous results.
- Exports default to `~/Desktop/Airu Compressed/`, use `name-comp.ext`, then `name-comp-2.ext`, and never overwrite originals. Directory locking, exclusive creation, Unicode normalization, and case folding handle collisions.
- New encodes retain the color profile and normalized orientation, but do not copy EXIF/GPS/XMP metadata. The lossless JPEG path preserves original metadata; unchanged copies preserve all original bytes.

## Supported deployment and limits

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
