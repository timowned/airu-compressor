# Using Airu from an AI agent

Use the native CLI directly with an argument array. The app does not need to be open. Image processing is offline, uses the same engine as the UI, and never needs a Figma connection, a shell, Homebrew, Node, or Python. The Python example below is caller code, not an Airu runtime requirement.

## Locate and discover

For an installed app, use its absolute helper path, for example `/Applications/Airu.app/Contents/MacOS/airu-cli`. For a packaged development build, use `dist/Airu.app/Contents/MacOS/airu-cli`. A raw `swift build` executable needs `--tools /absolute/path/to/Resources/Encoders`.

```sh
"/Applications/Airu.app/Contents/MacOS/airu-cli" capabilities --json
"/Applications/Airu.app/Contents/MacOS/airu-cli" doctor --json
```

`capabilities` returns one protocol-v1 event containing a versioned command contract: file counts, allowed/required options, possible terminal events, filesystem writes, option types/ranges/defaults, formats, modes, and exit codes. It requires no input or installed encoders. Use this contract instead of scraping help text. An omitted `maximumFiles` means no CLI count limit. Commands can also emit an `error` event; help is human-readable plain text.

`doctor` returns a structured `toolchain` report with absolute executable URLs, availability for every required tool, and a fingerprint when all are executable. A supplied incomplete `--tools` directory returns the full report and exit 1. If no tool directory can be resolved, it returns `missingToolchain`. Doctor checks files and hashes, not dynamic-library loading or actual encoding; a real preparation verifies that execution works.

## Preferred sequence

1. **Analyze** the original with `analyze FILE --json`. This validates contents, dimensions, color, actual transparency, orientation, and SHA-256 without compression or cache writes.
2. **Prepare** with `prepare FILE --format auto --mode airy --cache CACHE --json`. Read the `ready.result`, including measured size, selected format, verification, score, savings, and cache key. This writes a cached artifact but does not export.
3. **Export** with `export --key KEY --cache CACHE --destination DIR --json`. Read `exported.destinationURL`; the returned URL is the actual unique filename. Export validates and copies the prepared bytes without recompression.

Use the same explicit cache root for preparation and export. Keep the original available and unchanged through export: its hash is validated again. Treat cached artifacts as internal engine state; consume the exported URL rather than moving or modifying `cachedFileURL`.

`optimize FILE --destination DIR` combines preparation and export. `batch FILE... --destination DIR --concurrency 2` processes multiple inputs and preserves individual failures; omit destination to prepare only. Avoid launching many independent CLI processes: use the built-in batch concurrency limit. Defaults are two jobs and two encoder threads per job. Prefer explicit destinations so results go into the workflow's workspace.

Start with Auto + Airy for conservative website optimization. Choose Superlight for smaller PNG palettes with a measured SSIMULACRA2 target of at least 80. Airy PNG is pixel-lossless. Forced output formats can be larger; Auto cannot be larger than the original. Transparent images cannot be forced to JPEG. No mode resizes images.

## Consume events correctly

- Pass a unique `--request-id ID` for each invocation. After successful argument parsing, every event, including validation/processing errors, echoes `requestID`. IDs are 1...128 UTF-8 bytes without control characters. Invalid IDs and argument-parsing errors omit the ID. Also retain the subprocess-to-request mapping.
- Read stdout as UTF-8 NDJSON, one complete JSON object per line. `--json` suppresses progress; it does **not** turn multiple records into a single JSON object or array. Keep stderr separate. `optimize --json` normally emits both `ready` and `exported`.
- Check `protocolVersion == 1` and consecutive `sequence` values starting at 1. Tolerate unknown optional fields and future event/error codes. `requestID` is correlation only; it is not an idempotency key or persistent job ID.
- Success requires the expected terminal event **and** exit 0. `ready` alone does not prove export succeeded. For batches, inspect every job in `batchCompleted.batch.jobs`, retaining ready/completed successes even if exit status is 1.
- For live progress, omit `--json` and consume lines as they arrive. Fractions are 0...1, reflect measured work, and can pause during an encoder. They are not time estimates.
- `verification == ssimulacra2` means a measured score meets `result.options.minimumScore`. `unchangedOriginal` is a successful byte-identical passthrough, has no score, and can mean already optimized or too small to evaluate. Do not invent a score or treat it as a failure.
- URLs are absolute encoded `file:` URLs; decode them with a URL library. Sizes are actual bytes and savings is a percentage. Unicode, spaces, and option-like filenames work with argv arrays; use `--` before positional paths that start with `--`.
- Send SIGINT or SIGTERM to cancel. Wait for exit 130 and workspace cleanup. Set a caller deadline longer than the per-file optimization budget to allow analysis and export. For batches, allow multiple waves of jobs. Escalate to forced termination only if graceful shutdown fails.

Preparation is reusable: repeating the same source/options/toolchain hits the verified content cache. Export is **not** idempotent: repeating it creates `-comp-2`, `-comp-3`, etc. Retain successful exported URLs instead of blindly retrying an ambiguous export. Original files are never overwritten.

## Minimal caller example

This example uses only Python's standard library. Replace the paths with absolute paths in your workflow. It drains both streams, handles graceful cancellation on a caller timeout, and verifies terminal events. Use streaming stdout reading instead when live progress is needed.

```python
import json, pathlib, signal, subprocess, uuid

cli = "/Applications/Airu.app/Contents/MacOS/airu-cli"
source = pathlib.Path("/absolute/path/photo.png")
cache = pathlib.Path("/absolute/path/work/cache")
destination = pathlib.Path("/absolute/path/work/optimized")

def invoke(*arguments, terminal, deadline=480):
    request_id = str(uuid.uuid4())
    process = subprocess.Popen(
        [cli, *map(str, arguments), "--json", "--request-id", request_id],
        stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, text=True, encoding="utf-8",
    )
    try:
        stdout, stderr = process.communicate(timeout=deadline)
    except subprocess.TimeoutExpired:
        process.send_signal(signal.SIGINT)
        try:
            process.communicate(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.communicate()
        raise TimeoutError("Airu exceeded the caller deadline")
    events = [json.loads(line) for line in stdout.splitlines()]
    for sequence, event in enumerate(events, 1):
        if (event["protocolVersion"], event["sequence"], event.get("requestID")) != (1, sequence, request_id):
            raise RuntimeError("Unexpected Airu event stream")
    matches = [event for event in events if event["type"] == terminal]
    if process.returncode != 0 or not matches:
        raise RuntimeError({"exit": process.returncode, "events": events, "stderr": stderr})
    return matches[-1]

invoke("analyze", source, terminal="analysis")
ready = invoke("prepare", source, "--format", "auto", "--mode", "airy",
               "--cache", cache, terminal="ready")["result"]
exported = invoke("export", "--key", ready["cacheKey"], "--cache", cache,
                  "--destination", destination, terminal="exported")
print(exported["destinationURL"])
```

## Recovery

| Error | Next action |
| --- | --- |
| `usage`, `invalidOptions`, `invalidCacheKey` | Correct arguments from `capabilities`; validation occurs before tools or processing writes. Duplicate options and irrelevant command options are rejected. |
| `missingToolchain`, `missingEncoder` | Repair the app/tool bundle or supply the correct `--tools`; do not install arbitrary PATH executables. |
| `cacheInvalid`, `sourceChanged` | Analyze/prepare the current source again, then export its new cache key. |
| `authorizationRequired` | Use a writable workflow destination; GUI users can select an authorized folder in Airu. |
| `transparencyUnsupported` | Choose PNG, WebP, AVIF, or Auto; do not discard alpha. |
| `qualityThresholdUnmet`, `qualityEvaluationFailed` | Report the failure. Do not silently lower the requested threshold or accept unverified output. |
| `timeout` | Report exhausted work; retry only with a deliberately changed budget or workload. |
| `unsupportedImage`, `decodeFailed`, `animatedImage`, `unsupportedColor`, `imageTooLarge` | Report the per-file limitation and continue other batch jobs. |
| `cancelled` | Stop the workflow; exit 130 is expected. |

The complete event/model description is in [CLI_PROTOCOL.md](CLI_PROTOCOL.md). The app-bundled CLI uses the same contract; no additional automation server is needed.
