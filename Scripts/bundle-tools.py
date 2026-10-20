#!/usr/bin/env python3
"""Bundle exact, locked arm64 tools; recursively relocate every non-system dylib.

Development: --prefix /opt/homebrew
Reproduction: fetch-tools.py, then --prefix .build/toolchain
No Python or Homebrew is used by the resulting application.
"""
import argparse, hashlib, json, os, pathlib, re, shutil, subprocess, tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOOLS = {"avifenc": "libavif", "avifdec": "libavif", "cwebp": "webp", "dwebp": "webp",
         "cjpeg": "mozjpeg", "jpegtran": "mozjpeg", "oxipng": "oxipng", "ssimulacra2": "jpeg-xl", "pngquant": "pngquant"}

def run(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--prefix", type=pathlib.Path, default=pathlib.Path("/opt/homebrew"))
    parser.add_argument("--output", type=pathlib.Path, default=ROOT / "Resources/Encoders")
    args = parser.parse_args()
    lock = json.loads((ROOT / "Scripts/toolchain.lock.json").read_text())
    prefix = args.prefix.resolve()
    kegs = {f["name"]: prefix / "Cellar" / f["name"] / f["version"] for f in lock["formulae"]}
    for name, keg in kegs.items():
        if not keg.is_dir():
            raise SystemExit(f"Locked dependency missing: {keg}. Run fetch-tools.py to reproduce the lock.")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    staging = pathlib.Path(tempfile.mkdtemp(prefix=".tool-bundle-", dir=output.parent))
    try:
        for child in ("bin", "lib", "licenses"): (staging / child).mkdir()
        sources = {}
        queue = []
        def add(source, destination=None):
            source = source.resolve()
            if source in sources: return sources[source]
            if destination is None:
                identity = hashlib.sha256(source.read_bytes()).hexdigest()[:12]
                destination = pathlib.Path("lib") / (identity + "-" + source.name)
            sources[source] = destination
            shutil.copy2(source, staging / destination)
            os.chmod(staging / destination, 0o755)
            queue.append(source)
            return destination
        for tool, formula in TOOLS.items(): add(kegs[formula] / "bin" / tool, pathlib.Path("bin") / tool)
        def resolve(dep, source):
            dep = dep.replace("@@HOMEBREW_PREFIX@@", str(prefix)).replace("@@HOMEBREW_CELLAR@@", str(prefix / "Cellar"))
            if dep.startswith("/opt/homebrew/"): dep = str(prefix) + dep[len("/opt/homebrew"):]
            if dep.startswith("@loader_path/"): return pathlib.Path(str(source.parent) + dep[len("@loader_path"):])
            if dep.startswith("@rpath/"):
                name = dep[len("@rpath/"):]
                candidates = [source.parent / "../lib" / name] + [k / "lib" / name for k in kegs.values()]
                for c in candidates:
                    if c.exists(): return c
                raise RuntimeError(f"Unresolved {dep} in {source}")
            return pathlib.Path(dep)
        minimum_os = (14, 0)
        while queue:
            source = queue.pop(0)
            destination = staging / sources[source]
            arch = run("/usr/bin/lipo", "-archs", str(source)).strip().split()
            if "arm64" not in arch: raise RuntimeError(f"Not arm64: {source}")
            build = run("/usr/bin/vtool", "-show-build", str(source))
            for version in re.findall(r"minos\s+([\d.]+)", build):
                minimum_os = max(minimum_os, tuple(map(int, version.split("."))))
            dependencies = run("/usr/bin/otool", "-L", str(source)).splitlines()[1:]
            for line in dependencies:
                dep = line.strip().split(" (compatibility")[0]
                if dep.startswith(("/usr/lib/", "/System/Library/")): continue
                resolved = resolve(dep, source).resolve()
                if resolved == source: continue
                relocated = add(resolved)
                relative = os.path.relpath(staging / relocated, destination.parent)
                run("/usr/bin/install_name_tool", "-change", dep, "@loader_path/" + relative, str(destination))
            if sources[source].parts[0] == "lib":
                run("/usr/bin/install_name_tool", "-id", "@loader_path/" + destination.name, str(destination))
        for name, keg in kegs.items():
            folder = staging / "licenses" / name
            folder.mkdir()
            for path in keg.iterdir():
                if path.is_file() and re.match(r"(?i)(license|copying|notice|authors|patents|copyright)", path.name):
                    shutil.copy2(path, folder / path.name)
        artifacts = {}
        for destination in sorted(sources.values(), key=lambda p: p.parts[0] == "bin"):
            path = staging / destination
            run("/usr/bin/codesign", "--force", "--sign", "-", str(path))
            for line in run("/usr/bin/otool", "-L", str(path)).splitlines()[1:]:
                if not line.strip().startswith(("@loader_path/", "/usr/lib/", "/System/Library/")):
                    raise RuntimeError(f"Non-portable load command in {path}: {line}")
            artifacts[str(destination)] = hashlib.sha256(path.read_bytes()).hexdigest()
        manifest = {"schemaVersion": 1, "architecture": "arm64", "minimumMacOS": ".".join(map(str, minimum_os)),
                    "versions": {f["name"]: f["version"] for f in lock["formulae"]}, "sha256": artifacts,
                    "lockSHA256": hashlib.sha256((ROOT / "Scripts/toolchain.lock.json").read_bytes()).hexdigest()}
        (staging / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
        for child in ("bin", "lib", "licenses", "manifest.json"):
            target = output / child
            if target.is_dir(): shutil.rmtree(target)
            elif target.exists(): target.unlink()
            shutil.move(str(staging / child), target)
        print(f"Bundled {len(TOOLS)} tools and {len(sources)-len(TOOLS)} libraries; minimum macOS {manifest['minimumMacOS']}")
    finally:
        shutil.rmtree(staging)

if __name__ == "__main__": main()
