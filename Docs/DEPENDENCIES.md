# Locked dependencies and verified command interfaces

Investigated online release/formula documentation and the installed executables' actual help/version output on 2026-10-20. The authoritative artifact list, full source/archive URLs, licenses, versions, and bottle SHA-256 values are in `Scripts/toolchain.lock.json`; do not resolve “latest” during a reproducible build.

| Implementation | Locked version | Actual interface used |
| --- | --- | --- |
| libavif | 1.4.2 | `avifenc --jobs N --speed 6 --yuv 444 --qcolor Q --qalpha 100 [--lossless] --icc PROFILE INPUT OUTPUT` |
| libavif decoder | 1.4.2 | `avifdec --jobs 2 INPUT OUTPUT.png` |
| libwebp | 1.6.0 | `cwebp -m 6 -q Q -alpha_q 100 -exact -metadata icc [-lossless or -sharp_yuv] -o OUTPUT -- INPUT` |
| MozJPEG | 4.1.5 | `cjpeg -quality Q -sample 1x1 -optimize -progressive -icc PROFILE -outfile OUTPUT INPUT.png` |
| MozJPEG | 4.1.5 | `jpegtran -copy all -optimize -progressive -outfile OUTPUT ORIGINAL.jpg` |
| OxiPNG | 10.2.1 | `oxipng -o 3 --nc --threads N --out OUTPUT INPUT.png` |
| libjxl SSIMULACRA2 | 0.12.0 (bottle revision 1) | `ssimulacra2 REFERENCE.png DISTORTED.png`; scalar score on stdout |

AVIF quality 100 plus lossless mode is a true lossless fallback. WebP quality 100 without `-lossless` is still lossy. JPEG retains a lossless coefficient-optimization path and separately searches MozJPEG's lossy scale. OxiPNG does not use unsafe stripping or alpha alteration. The `dwebp` companion is bundled for diagnostics/future decoder fallback; native WebP ImageIO decoding is exercised in the current engine.

Upstream references: [libavif encoder interface](https://github.com/AOMediaCodec/libavif/blob/main/doc/avifenc.1.md), [WebP cwebp reference](https://developers.google.com/speed/webp/docs/cwebp), [MozJPEG](https://github.com/mozilla/mozjpeg), [OxiPNG](https://github.com/oxipng/oxipng), [SSIMULACRA2 source](https://github.com/libjxl/libjxl/blob/main/tools/ssimulacra2_main.cc). Release artifact metadata: [libavif](https://formulae.brew.sh/api/formula/libavif.json), [WebP](https://formulae.brew.sh/api/formula/webp.json), [MozJPEG](https://formulae.brew.sh/api/formula/mozjpeg.json), [OxiPNG](https://formulae.brew.sh/api/formula/oxipng.json), [libjxl](https://formulae.brew.sh/api/formula/jpeg-xl.json).

`fetch-tools.py` reconstructs an isolated prefix from immutable GHCR bottle URLs, verifies every archive hash, and confines extraction to the declared formula. It supports replaying previously downloaded archives via `--archives DIR`. `bundle-tools.py` reads this prefix (or a matching development Homebrew installation), copies the eight tools, resolves the complete non-system dylib closure, rewrites load commands to relative loader paths, verifies arm64, records minimum OS versions, collects licenses, and ad hoc signs native files. Name prefixes distinguish libraries that could otherwise collide. It refuses unresolved/nonportable load commands.

The checked bundle contains 8 tools and 28 non-system dylibs. The manifest records exact bundled file hashes, lock hash, and macOS 27.0 minimum. A lock replay from downloaded archives and runtime compression using that independently assembled bundle are part of verification. These are reproducible dependency inputs and packaging steps; bit-for-bit reproducibility of the Swift compiler output or Developer ID timestamped signatures is not claimed.

No codec is implemented in Swift. The engine executes absolute executable URLs with typed request models and argument arrays. Subprocess output goes to job-local files to avoid pipe deadlocks; stdout parsing is bounded. Nonzero exit codes, missing executables, invalid metric output, dimensional/alpha changes, and deadlines surface as explicit errors. AVIF is reference-decoded and materialized before removing temporary decoded files. Foundation `waitUntilExit` is intentionally avoided on cooperative executor threads.
