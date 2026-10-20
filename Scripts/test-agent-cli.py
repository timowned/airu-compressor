#!/usr/bin/env python3
"""Exercise the agent contract against the native executable and real bundled codecs."""
import hashlib
import fcntl
import json
import os
import pathlib
import signal
import subprocess
import tempfile
import urllib.parse

ROOT = pathlib.Path(__file__).resolve().parent.parent
CLI = pathlib.Path(os.environ.get("AIRU_TEST_CLI", ROOT / ".build/debug/airu")).resolve()
TOOLS = ROOT / "Resources/Encoders"
FIXTURES = ROOT / "Packages/AiruCore/Tests/AiruCoreTests/Fixtures"


def check(condition, message):
    if not condition:
        raise AssertionError(message)


def decode(text, request_id=None):
    events = [json.loads(line) for line in text.splitlines()]
    check(events, "Empty protocol stream")
    for index, event in enumerate(events, 1):
        check(event["protocolVersion"] == 1 and event["sequence"] == index, "Unordered protocol")
        if request_id is not None:
            check(event.get("requestID") == request_id, "Lost correlation ID")
    return events


with tempfile.TemporaryDirectory(prefix="airu-agent-") as temp:
    directory = pathlib.Path(temp)
    cache = directory / "cache"
    destination = directory / "outputs"
    request_id = "agent/日本語/42"

    def run(*args, expected=0, correlate=True):
        argv = [str(CLI), *map(str, args)]
        if correlate:
            argv += ["--request-id", request_id]
        completed = subprocess.run(argv, capture_output=True, text=True, timeout=120)
        check(completed.returncode == expected, f"{argv}: {completed.stdout}\n{completed.stderr}")
        check(not completed.stderr, f"Unexpected diagnostics: {completed.stderr}")
        return decode(completed.stdout, request_id if correlate else None)

    # Discovery is independent of tool installation, input files and cache creation.
    contract = run("capabilities", "--json", "--tools", directory / "absent-tools", "--cache", cache)[0]["capabilities"]
    check(not cache.exists(), "Discovery created a cache")
    check(contract["transport"] == "ndjson" and contract["modeScoreDefaults"]["superlight"] == 80, "Wrong discovery defaults")
    commands = {command["name"]: command for command in contract["commands"]}
    check(set(commands) == {"help", "capabilities", "doctor", "analyze", "prepare", "optimize", "batch", "export"}, "Incomplete discovery")
    check(commands["prepare"]["maximumFiles"] == 1 and "--key" in commands["export"]["requiredOptions"], "Missing argument contract")
    check(contract["defaultOptimizationOptions"]["minimumScore"] == 90, "Changed default quality")
    check("--request-id" in contract["globalOptions"], "Missing correlation discovery")
    for command in commands:
        help_result = subprocess.run([str(CLI), command, "--help"], capture_output=True, text=True, timeout=10)
        check(help_result.returncode == 0 and "capabilities" in help_result.stdout, "Command help failed")

    # Agent mistakes must fail before tool discovery or destination/cache writes.
    invalid = [
        ["unknown"], ["prepare"], ["prepare", "one.png", "two.png"],
        ["export", "--key", "a" * 64, "unexpected.png"],
        ["prepare", "missing.png", "--destination", destination],
        ["analyze", "missing.png", "--format", "png"],
        ["optimize", "missing.png", "--concurrency", "2"],
        ["prepare", "missing.png", "--format", "png", "--format", "webp"],
        ["prepare", "missing.png", "--score", "nan"],
        ["batch", "missing.png", "--mode", "superlight", "--score", "79"],
    ]
    for args in invalid:
        events = run(*args, "--tools", directory / "absent-tools", "--cache", cache, expected=1,
                     correlate=args.count("--format") < 2)
        check(len(events) == 1 and events[0]["error"]["code"] in ("usage", "invalidOptions"), "Late argument validation")
    check(not cache.exists() and not destination.exists(), "Invalid invocation wrote files")
    run("export", "--key", "../escape", expected=1)
    for bad_id in ("", "x" * 129, "line\nbreak"):
        events = run("capabilities", "--request-id", bad_id, expected=1, correlate=False)
        check(events[0]["error"]["code"] == "usage" and "requestID" not in events[0], "Invalid ID echoed")
    for args in (["optimize", "file.png", "--destination", "--json"], ["prepare", "file.png", "--format"]):
        check(run(*args, expected=1, correlate=False)[0]["error"]["code"] == "usage", "Missing option value accepted")

    broken = run("doctor", "--tools", directory / "absent-tools", expected=1)[0]
    check(broken["type"] == "toolchain" and not broken["toolchain"]["allExecutable"], "Missing structured doctor failure")
    check(all(not tool["executable"] for tool in broken["toolchain"]["tools"]), "Missing tools reported as present")
    healthy = run("doctor", "--tools", TOOLS)[0]["toolchain"]
    check(healthy["allExecutable"] and len(healthy["fingerprint"]) == 64, "Toolchain fingerprint missing")

    # Real two-step workflow with Unicode, spaces and an option-like filename.
    source = directory / "--日本語 photograph.png"
    source.write_bytes((FIXTURES / "palette-graphic.png").read_bytes())
    original_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    info = run("analyze", "--json", source)[0]["analysis"]
    check(info["canDecode"] and info["fileSize"] == source.stat().st_size, "Analysis mismatch")
    common = ["--cache", cache, "--tools", TOOLS, "--format", "png", "--mode", "superlight", "--candidates", "6"]
    prepared = run("prepare", source, *common)
    check(prepared[0]["progress"]["fraction"] == 0 and prepared[-1]["type"] == "ready", "Invalid workflow progress")
    result = prepared[-1]["result"]
    check(result["perceptualScore"] >= 80 and result["outputSize"] < info["fileSize"], "Unverified or ineffective compression")
    check(not destination.exists(), "Prepare exported unexpectedly")
    reused = run("prepare", source, *common, "--json")
    check(reused[0]["result"]["cacheKey"] == result["cacheKey"], "Cache identity changed")
    # Export needs no tools. Repeating it creates a unique copy, never an overwrite.
    urls = []
    for _ in range(2):
        event = run("export", "--key", result["cacheKey"], "--cache", cache, "--destination", destination)[0]
        exported = pathlib.Path(urllib.parse.unquote(urllib.parse.urlparse(event["destinationURL"]).path))
        urls.append(exported)
        check(exported.stat().st_size == result["outputSize"], "Exported size mismatch")
        check(hashlib.sha256(exported.read_bytes()).hexdigest() == result["outputSHA256"], "Exported checksum mismatch")
        decoded = run("analyze", exported)[0]["analysis"]
        check((decoded["width"], decoded["height"]) == (info["width"], info["height"]), "Image dimensions changed")
    check(urls[0] != urls[1] and hashlib.sha256(source.read_bytes()).hexdigest() == original_hash, "Original or export overwritten")
    auto = run("prepare", source, "--cache", cache, "--tools", TOOLS, "--format", "auto", "--candidates", "4", "--json")[0]["result"]
    check(auto["outputSize"] <= info["fileSize"], "Auto enlarged input")
    mixed = run("batch", source, directory / "missing.png", *common, "--json", expected=1)[-1]["batch"]
    check(sorted(job["status"] for job in mixed["jobs"]) == ["failed", "ready"], "Partial batch failure lost valid result")

    # Cancel a fresh real invocation after its first progress event, preserving correlation.
    process = subprocess.Popen([str(CLI), "prepare", str(FIXTURES / "photo.jpg"), "--format", "avif",
                                "--tools", str(TOOLS), "--cache", str(directory / "cancel-cache"),
                                "--request-id", request_id], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        first = process.stdout.readline()
        check(json.loads(first)["type"] == "progress", "No cancellable progress")
        process.send_signal(signal.SIGINT)
        stdout, stderr = process.communicate(timeout=15)
        events = decode(first + stdout, request_id)
        check(process.returncode == 130 and events[-1]["error"]["code"] == "cancelled", "Cancellation contract failed")
    finally:
        if process.poll() is None:
            process.kill()
            process.communicate()

    # Hold the actual export lock so cancellation during Step B is deterministic.
    # An agent cancellation must not be swallowed as a successful partial batch.
    blocked_destination = directory / "blocked-export"
    blocked_destination.mkdir()
    with (blocked_destination / ".airu-export.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        process = subprocess.Popen([str(CLI), "batch", str(source), *map(str, common),
                                    "--destination", str(blocked_destination), "--request-id", request_id],
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        prefix = ""
        try:
            while True:
                line = process.stdout.readline()
                check(line, "Batch ended before export started")
                prefix += line
                event = json.loads(line)
                if event["type"] == "batchProgress" and any(job["status"] == "exporting" for job in event["batch"]["jobs"]):
                    break
            process.send_signal(signal.SIGINT)
            stdout, stderr = process.communicate(timeout=15)
            events = decode(prefix + stdout, request_id)
            check(process.returncode == 130 and events[-1]["error"]["code"] == "cancelled", "Batch export swallowed cancellation")
            check(list(blocked_destination.iterdir()) == [blocked_destination / ".airu-export.lock"], "Cancelled export left an artifact")
        finally:
            if process.poll() is None:
                process.kill()
                process.communicate()

print("Agent CLI checks passed: discovery, validation, correlation, doctor, real prepare/export, cache reuse, Auto size, batch isolation, preparation/export cancellation")
