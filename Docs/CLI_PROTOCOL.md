# CLI protocol v1

All processing commands write UTF-8 NDJSON to stdout, one complete JSON object per line. Tool stdout/stderr is captured internally and never mixed into the event stream. Build/help text is not part of the processing protocol. Fatal errors also emit a structured `error` record. `--json` suppresses progress; each terminal record remains a separate JSON object, so `optimize` can return `ready` followed by `exported`. It does not wrap multiple records in an array.

Every record has `protocolVersion: 1`, `sequence` (starts at 1 for each CLI invocation), and `type`. Optional fields are omitted when absent. Codable URLs are absolute `file:` URL strings; decode URL escaping before treating them as filesystem paths. Sizes are signed 64-bit byte counts, progress is 0...1, savings is a percentage (negative for larger forced conversions), and scores are finite measured doubles. Do not treat an omitted score as zero.

For agent integrations, start with `airu capabilities --json` and [the agent workflow guide](AGENT_WORKFLOW.md). `--request-id ID` adds `requestID` to all events after successful argument parsing, including validation and runtime failures. IDs must contain 1...128 UTF-8 bytes without control characters. Invalid IDs and argument-parsing errors omit correlation; maintain a subprocess-to-request mapping too. Correlation does not change cache identity or make export idempotent.

| type | Fields | Meaning |
| --- | --- | --- |
| analysis | sourceURL, analysis | Content validation and source metadata |
| progress | sourceURL, progress | analyzing/optimizing/ready, fraction, message, optional measured candidate |
| ready | sourceURL, result | Verified cached artifact, size, score/verification, options, candidate history, cacheKey |
| exported | sourceURL (when known), destinationURL | Copy completed and checksum verified |
| batchProgress | batch | Complete current snapshot; jobs, total progress, isFinished |
| batchCompleted | batch | Terminal snapshot including individual failures |
| error | error, optional sourceURL | Stable error code plus human-readable message |
| toolchain | message, toolchain, optional error | Doctor's per-tool availability/fingerprint report; incomplete explicit tool bundles exit 1 |
| capabilities | capabilities | Versioned command/option contract, defaults, terminal events, write effects, exit codes; no tools required |

Example records (shortened fields here only):

```json
{"protocolVersion":1,"sequence":1,"type":"progress","progress":{"status":"analyzing","fraction":0,"message":"Reading and validating image"}}
{"protocolVersion":1,"sequence":2,"type":"error","error":{"code":"missingEncoder","message":"Required bundled executable is missing: ..."}}
```

Commands:

```sh
airu capabilities [--json]
airu analyze FILE... [--json]
airu prepare FILE [OPTIONS]
airu optimize FILE [--destination DIR] [OPTIONS]
airu batch FILE... [--destination DIR] [--concurrency 2] [OPTIONS]
airu export --key SHA256 [--cache DIR] [--destination DIR]
airu doctor --tools DIR
```

Options: `--mode airy|superlight` (default Airy), `--format auto|avif|webp|jpeg|png` (`jpg` alias accepted), `--score N` (90 for Airy, 80 for Superlight; Superlight minimum 80), `--candidates 24` (4...64), `--timeout 180` (1...3600 seconds), `--threads 2` (1...8), `--tools DIR`, `--cache DIR`, `--json`. Put `--` before filenames starting with option prefixes. CLI concurrency is 1...8. Analysis/export do not require an encoder directory.

Global options are `--json`, `--request-id`, `--tools`, `--cache`, and `--help` (`-h` alias). Tools/cache are accepted globally for compatibility but unused by discovery/analysis. `COMMAND --help` prints usage without processing. Unknown commands, duplicate options, inappropriate command options, incorrect file counts, invalid keys, and invalid optimization limits fail before tool discovery or writes. Use `./` for option values whose path starts with `--`; the `--` separator applies to positional files only. Command-specific options and constraints are defined by the same Swift contract returned by `capabilities`.

`capabilities.contractVersion` and `eventProtocolVersion` are currently 1. The payload contains `commands` with `minimumFiles`, optional `maximumFiles` (omitted means unbounded), `options`, `requiredOptions`, `terminalEvents`, and `writes`. Option descriptors provide `name`, `valueType`, optional `allowedValues`, `defaultValue` (descriptive string), and numeric bounds. `defaultOptimizationOptions` provides typed defaults; `modeScoreDefaults` describes implicit mode-specific score selection. Fatal errors can replace a command's normal terminal events; batch errors can coexist with successes.

`toolchain` contains `directoryURL`, `tools` (`name`, `executableURL`, `executable`), `allExecutable`, and optional `fingerprint`. Doctor checks executable availability and hashes, not dynamic-library loading or actual encoder execution. No resolvable bundle yields an `error` record with `missingToolchain`.

Tool location priority: `--tools`, `AIRU_ENCODER_DIR`, bundled `Resources/Encoders` next to the CLI/application. No global PATH resolution. Cache defaults to the user's `Library/Caches/Airu/v1`.

Exit status: 0 success, 1 validation/processing/export failure (also when any batch job fails), 130 cancellation. SIGINT/SIGTERM cancel active preparation, terminate encoder processes, and clean job workspaces. One malformed image does not stop other batch files. Use `BatchProcessor` directly for interactive add/remove; CLI `batch` consumes its initial file list.

Important error codes include `unsupportedImage`, `decodeFailed`, `animatedImage`, `unsupportedColor`, `imageTooLarge`, `missingToolchain`, `missingEncoder`, `processFailed`, `timeout`, `qualityEvaluationFailed`, `qualityThresholdUnmet`, `comparisonImageTooSmall`, `alphaMismatch`, `dimensionMismatch`, `transparencyUnsupported`, `cacheInvalid`, `sourceChanged`, `authorizationRequired`, `invalidOptions`, `invalidCacheKey`, `notReady`, `cancelled`, `usage`, and `io`. Consumers should tolerate new codes and optional fields in future protocol-v1 releases.

Job states: queued → analyzing → optimizing → ready → exporting → completed. Failures and cancellation are terminal for that job. `BatchSnapshot.isFinished` also treats ready as preparation-complete. The actor allows jobs to be added after a completed preparation wave. For a changed format, call `prepare` with new options or replace the batch job; the source/options cache key selects or generates the right artifact.

Auto skips codecs incompatible with the original dimensions; forcing one returns `codecDimensionLimit` without resizing. Budget expiry retains only earlier fully verified candidates; a timeout with no acceptable candidate remains an error. Interrupted probes never appear in the accepted result. Non-timeout evaluator failures still return explicit errors even when an earlier candidate passed. Oversized export names are shortened at Unicode character boundaries, reserving suffix/counter/extension space. Unresolvable filename/path length errors return `filenameTooLong`; other non-permission creation errors return `exportFailed` instead of requesting a folder authorization flow.

PNG output uses OxiPNG alone in Airy and libimagequant/pngquant followed by OxiPNG in Superlight. `result.options.pngMode` carries the selected pipeline. Lossless PNG records have `lossless: true` and omit `quality`; palette records have `lossless: false` and a quantizer quality parameter. That parameter is not a perceptual score. Every recorded `score` is measured by SSIMULACRA2; rejected alpha-changing probes emit progress only. Mode is part of cache identity. The UI must pass `--mode` as well as `--score`; changing only the score does not enable palette quantization.
