#!/usr/bin/env python3
"""Black-box tests of the actual native CLI protocol, cache-only export, and packaged tool loading."""
import hashlib, json, os, pathlib, signal, subprocess, tempfile, time, urllib.parse

ROOT = pathlib.Path(__file__).resolve().parent.parent
CLI = pathlib.Path(os.environ.get("AIRU_TEST_CLI", ROOT / ".build/debug/airu"))
FIXTURES = ROOT / "Packages/AiruCore/Tests/AiruCoreTests/Fixtures"
TOOLS = ROOT / "Resources/Encoders"

def check(condition, message):
    if not condition: raise AssertionError(message)

with tempfile.TemporaryDirectory(prefix="airu-cli-test-") as temp:
    directory = pathlib.Path(temp)
    common = ["--tools", str(TOOLS), "--cache", str(directory / "cache")]
    def run(*arguments, expected=0, include_tools=True):
        command = [str(CLI), *map(str, arguments), *(common if include_tools else [])]
        completed = subprocess.run(command, capture_output=True, text=True, timeout=120)
        check(completed.returncode == expected, f"{command}: {completed.stdout}\n{completed.stderr}")
        events = [json.loads(line) for line in completed.stdout.splitlines()]
        check(all(e["protocolVersion"] == 1 and e["sequence"] == i + 1 for i, e in enumerate(events)), "Invalid event sequence")
        return events
    info = run("analyze", FIXTURES / "photo.jpg", "--json")
    check(info[0]["analysis"]["format"] == "jpeg", "Content analysis failed")
    progress = run("prepare", FIXTURES / "photo.jpg", "--format", "avif", "--candidates", "6")
    check(any(e["type"] == "progress" for e in progress), "Missing progress events")
    result = next(e["result"] for e in progress if e["type"] == "ready")
    check(result["perceptualScore"] >= 90, "Quality threshold failed")
    check(result["outputSize"] == min(c["bytes"] for c in result["candidates"] if c["score"] >= 90), "Did not choose measured minimum")
    key = result["cacheKey"]
    # No --tools argument or PATH lookup is needed for Step B.
    events = run("export", "--key", key, "--cache", directory / "cache", "--destination", directory / "custom output", include_tools=False)
    exported = pathlib.Path(urllib.parse.unquote(urllib.parse.urlparse(events[0]["destinationURL"]).path))
    check(exported.stat().st_size == result["outputSize"], "Reported size differs from exported bytes")
    check(hashlib.sha256(exported.read_bytes()).hexdigest() == result["outputSHA256"], "Export checksum differs")
    reused = run("prepare", FIXTURES / "photo.jpg", "--format", "avif", "--candidates", "6")
    check(len(reused) == 3 and reused[-1]["result"]["cacheKey"] == key, "Cache was not reused")
    webp = run("optimize", FIXTURES / "transparent.png", "--format", "webp", "--candidates", "4", "--destination", directory / "transparent", "--json")
    check(webp[-1]["type"] == "exported", "Transparent WebP export failed")
    batch = run("batch", FIXTURES / "photo.png", directory / "missing.png", "--format", "png", "--destination", directory / "batch", "--json", expected=1)
    final = batch[-1]["batch"]
    check(final["isFinished"] and final["progress"] == 1, "Missing final batch progress")
    check(sorted(j["status"] for j in final["jobs"]) == ["completed", "failed"], "One file error stopped the batch")
    run("prepare", FIXTURES / "photo.jpg", "--score", "nan", expected=1)
    run("export", "--key", "../escape", "--cache", directory / "cache", "--destination", directory, expected=1, include_tools=False)
    check(run("doctor")[0]["type"] == "toolchain", "Toolchain discovery failed")
    airy_events = run("prepare", FIXTURES / "palette-graphic.png", "--format", "png", "--mode", "airy", "--json")
    airy = airy_events[-1]["result"]
    check(airy["options"]["pngMode"] == "airy" and all(c["lossless"] for c in airy["candidates"]), "Airy PNG must remain lossless")
    light_events = run("optimize", FIXTURES / "palette-graphic.png", "--format", "png", "--mode", "superlight",
                       "--destination", directory / "palette", "--json")
    light = light_events[0]["result"]
    check(light["options"]["minimumScore"] == 80 and light["perceptualScore"] >= 80, "Superlight PNG requires measured score >=80")
    check(light["outputSize"] < airy["outputSize"] and light["cacheKey"] != airy["cacheKey"], "PNG mode selection/cache separation failed")
    check(any(not c["lossless"] and c["bytes"] == light["outputSize"] for c in light["candidates"]), "Palette pipeline was not selected")
    check(light_events[-1]["type"] == "exported", "Palette PNG export failed")
    run("prepare", FIXTURES / "photo.png", "--mode", "superlight", "--score", "79", expected=1)
    run("prepare", FIXTURES / "photo.png", "--mode", "invalid", expected=1)
    packaged = ROOT / "dist/Airu.app/Contents/MacOS/airu-cli"
    if packaged.exists():
        # No development tool directory, Homebrew executable, or inherited DYLD path.
        env = {"PATH": "/usr/bin:/bin", "HOME": str(directory), "TMPDIR": temp}
        completed = subprocess.run([str(packaged), "prepare", str(FIXTURES / "photo.jpg"), "--format", "avif",
                                    "--candidates", "4", "--cache", str(directory / "packaged-cache"), "--json"],
                                   env=env, capture_output=True, text=True, timeout=90)
        check(completed.returncode == 0, f"Bundled execution failed: {completed.stdout} {completed.stderr}")
        check(json.loads(completed.stdout)["result"]["perceptualScore"] >= 90, "Packaged quality verification failed")
    print("CLI checks passed: analysis, progress, quality, measured selection, cache reuse, cache-only export, alpha, batch errors, options, key validation, tool discovery, packaged offline runtime")
