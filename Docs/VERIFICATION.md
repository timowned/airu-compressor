# Stage 1 verification record

Verified 2026-10-20 on Apple Silicon, macOS 27.0.1, Swift 6.2.3, Xcode 26.2/macOS SDK 26.2. The package compiles in Swift 6 language mode with concurrency checking.

## Final results

- `bash Scripts/test.sh`: **24 Swift tests passed**, including parameterized transparency and ICC cases; full suite completed in 30.224 seconds. Black-box CLI checks also passed. See `Tests/test-results.log`.
- `bash Scripts/build.sh`: release native CLI and Xcode app built successfully. See `Tests/release-build.log`.
- `codesign --verify --deep --strict dist/Airu.app`: passed.
- Both development and application encoder manifests: all 36 native artifacts (8 tools, 28 libraries) match their recorded SHA-256 values.
- Isolated replay of all 22 pinned dependency archives passed checksum verification. An independently relocated bundle from that isolated prefix encoded/exported the JPEG fixture with the same 81,843-byte output and SHA-256 as the development bundle.
- Packaged CLI preparation passed with only `/usr/bin:/bin` in PATH, a temporary HOME, no `--tools`, and no `AIRU_ENCODER_DIR` or DYLD override. Its actual encoder invocations resolve within the application.

## End-to-end release demonstration

```sh
dist/Airu.app/Contents/MacOS/airu-cli optimize \
  Packages/AiruCore/Tests/AiruCoreTests/Fixtures/photo.png \
  --format auto --cache .cache/release-demo \
  --destination Tests/Output --json
```

The complete machine-readable result is saved in `Tests/end-to-end.ndjson`.

| Measured property | Result |
| --- | --- |
| Real photographic source | 550×368 PNG, 375,229 bytes |
| Evaluated candidates | 19, spanning PNG, AVIF, WebP, JPEG |
| Selected output | AVIF, 103,487 bytes |
| SSIMULACRA2 | 90.84645625 (target 90) |
| Savings | 72.4203% |
| Exported file | `Tests/Output/photo-comp-2.avif` |
| Export size/checksum match | Passed |
| Dimensions retained | 550×368 |

The earlier JPEG-to-AVIF run used the real 113,946-byte JPEG fixture and produced 81,843 bytes at score 90.244169 (28.1739% savings). Its output is in `Tests/Output/photo-comp.avif`; the independently reproduced bundle's equivalent output is in `Tests/ReproducedOutput/photo-comp.avif`.

## Coverage requested for Stage 1

| Requirement | Evidence |
| --- | --- |
| JPEG / PNG compression | `jpegCompression`, `pngCompression`, actual native encoders |
| AVIF / WebP export | `avifExport`, `webpExport`, decode, size, checksum assertions |
| Transparent PNG | Parameterized AVIF/WebP/PNG, exact alpha comparison and both matte scores |
| Small unchanged files | `autoSmallFileAndMeasuredMinimum`, explicit minimum-size conversion error |
| EXIF orientation | Metadata and rotated compression tests; 550×368 storage becomes 368×550 visual dimensions |
| ICC profiles | Display P3 fixture across all four output codecs, profile and color-managed quality checks |
| Unicode / spaces / identical names | Unicode collision test and two-directory batch export test |
| Batch processing | Concurrent successful jobs plus an individual failed image; dynamic removal |
| Cancellation | Encoder preparation cancellation, batch cancellation, and blocked export cancellation |
| Unsupported/corrupted files | Content/extension mismatch and malformed source rejection |
| Missing encoders | Explicit missing-tool errors |
| Quality threshold | Minimum accepted size assertions, strict score 98 search, missing/failing evaluator rejection |
| Cache reuse/invalidation | File modification time unchanged on reuse; source mutation and output tampering invalidate entries |
| Custom export folder | Export, Unicode, and CLI tests |
| Machine protocol | JSON decoding, ordered sequence/version fields, progress, batch terminal state, error exit codes |
| Safe process execution | Argument literal handling and real process timeout test |
| Offline distribution | Packaged-runtime test and isolated archive replay |

## Practical limits

The pinned native binary distribution requires arm64 macOS 27+. The current input pipeline explicitly rejects higher-bit-depth, CMYK, HDR gain-map and multi-frame content. Images smaller than 8×8 use an unchanged copy when appropriate because upstream SSIMULACRA2 cannot score them. No numerical score is invented for that path. These are documented product limits, not silent fallbacks.

Developer ID notarization, testing on a second physical Mac, older-macOS toolchain builds, and App Store sandbox validation remain distribution/integration work. Apple signing credentials are not available in this workspace. The native SwiftUI Auto interface is implemented in Stage 2; see [frontend integration](STAGE2.md).

## Stage 2 frontend verification — 2026-10-20

`bash Scripts/test.sh` now passes **24 engine tests + 13 frontend tests**, plus all black-box CLI checks. The final run took 30.309 seconds for the engine suite and 32.249 seconds for the frontend suite. See `Tests/stage2-all-tests.log`. `bash Scripts/build.sh` and deep/strict signature validation pass; see `Tests/stage2-build.log`.

The GUI used the bundled `airu-cli` to prepare and export a real JPEG to a folder selected with NSOpenPanel. The final export `Tests/UIExports/photo-comp-2.avif` decodes at 550×368 and contains 81,843 bytes. It matches the earlier accepted AVIF's SHA-256 exactly; the original output was preserved and the new name received the `-2` suffix. See `Tests/ui-export-verification.json`.

Native UI checks and real screenshots cover empty, processing, completed, format-menu and Manual states. Manual shows only “Coming soon...”; the top controls use Apple Liquid Glass. Details and the outstanding hands-on Finder drop check are recorded in [frontend integration](STAGE2.md). These development builds remain unnotarized and require arm64 macOS 27+.
