# CLI protocol v1

All processing commands write UTF-8 NDJSON to stdout, one complete JSON object per line. Tool stdout/stderr is captured internally and never mixed into the event stream. Build/help text is not part of the processing protocol. Fatal errors also emit a structured `error` record. `--json` suppresses progress; each terminal record remains a separate JSON object, so `optimize` can return `ready` followed by `exported`. It does not wrap multiple records in an array.

Every record has `protocolVersion: 1`, `sequence` (starts at 1 for each CLI invocation), and `type`. Optional fields are omitted when absent. Codable URLs are absolute `file:` URL strings; decode URL escaping before treating them as filesystem paths. Sizes are signed 64-bit byte counts, progress is 0...1, savings is a percentage (negative for larger forced conversions), and scores are finite measured doubles. Do not treat an omitted score as zero.

| type | Fields | Meaning |
| --- | --- | --- |
| analysis | sourceURL, analysis | Content validation and source metadata |
| progress | sourceURL, progress | analyzing/optimizing/ready, fraction, message, optional measured candidate |
| ready | sourceURL, result | Verified cached artifact, size, score/verification, options, candidate history, cacheKey |
| exported | sourceURL (when known), destinationURL | Copy completed and checksum verified |
| batchProgress | batch | Complete current snapshot; jobs, total progress, isFinished |
| batchCompleted | batch | Terminal snapshot including individual failures |
| error | error, optional sourceURL | Stable error code plus human-readable message |
| toolchain | message | Doctor's executable/fingerprint report |

Example records (shortened fields here only):

```json
{"protocolVersion":1,"sequence":1,"type":"progress","progress":{"status":"analyzing","fraction":0.02,"message":"Reading and validating image"}}
{"protocolVersion":1,"sequence":2,"type":"error","error":{"code":"missingEncoder","message":"Required bundled executable is missing: ..."}}
```

Commands:

```sh
airu analyze FILE... [--json]
airu prepare FILE [OPTIONS]
airu optimize FILE [--destination DIR] [OPTIONS]
airu batch FILE... [--destination DIR] [--concurrency 2] [OPTIONS]
airu export --key SHA256 [--cache DIR] [--destination DIR]
airu doctor --tools DIR
```

Options: `--format auto|avif|webp|jpeg|png` (`jpg` alias accepted), `--score 90`, `--candidates 24` (4...64), `--timeout 180` (1...3600 seconds), `--threads 2` (1...8), `--tools DIR`, `--cache DIR`, `--json`. Put `--` before filenames starting with option prefixes. CLI concurrency is 1...8. Analysis/export do not require an encoder directory.

Tool location priority: `--tools`, `AIRU_ENCODER_DIR`, bundled `Resources/Encoders` next to the CLI/application. No global PATH resolution. Cache defaults to the user's `Library/Caches/Airu/v1`.

Exit status: 0 success, 1 validation/processing/export failure (also when any batch job fails), 130 cancellation. SIGINT/SIGTERM cancel active preparation, terminate encoder processes, and clean job workspaces. One malformed image does not stop other batch files. Use `BatchProcessor` directly for interactive add/remove; CLI `batch` consumes its initial file list.

Important error codes include `unsupportedImage`, `decodeFailed`, `animatedImage`, `unsupportedColor`, `imageTooLarge`, `missingToolchain`, `missingEncoder`, `processFailed`, `timeout`, `qualityEvaluationFailed`, `qualityThresholdUnmet`, `comparisonImageTooSmall`, `alphaMismatch`, `dimensionMismatch`, `transparencyUnsupported`, `cacheInvalid`, `sourceChanged`, `authorizationRequired`, `invalidOptions`, `invalidCacheKey`, `notReady`, `cancelled`, `usage`, and `io`. Consumers should tolerate new codes and optional fields in future protocol-v1 releases.

Job states: queued → analyzing → optimizing → ready → exporting → completed. Failures and cancellation are terminal for that job. `BatchSnapshot.isFinished` also treats ready as preparation-complete. The actor allows jobs to be added after a completed preparation wave. For a changed format, call `prepare` with new options or replace the batch job; the source/options cache key selects or generates the right artifact.
