#!/usr/bin/env python3
"""Fetch immutable Homebrew bottles by SHA-256 into an isolated prefix, without installing Homebrew."""
import argparse, hashlib, json, os, pathlib, shutil, tarfile, urllib.request, urllib.parse

ROOT = pathlib.Path(__file__).resolve().parent.parent
PREFIX = ROOT / ".build/toolchain"
DOWNLOADS = ROOT / ".build/downloads"
lock = json.loads((ROOT / "Scripts/toolchain.lock.json").read_text())
parser = argparse.ArgumentParser()
parser.add_argument("--archives", type=pathlib.Path, help="Optional directory containing previously downloaded bottle tarballs")
parser.add_argument("--only", choices=[f["name"] for f in lock["formulae"]], help="Fetch one locked dependency into an existing prefix")
args = parser.parse_args()
existing = {}
if args.archives:
    for candidate in args.archives.glob("*.tar.gz"):
        existing[hashlib.sha256(candidate.read_bytes()).hexdigest()] = candidate
DOWNLOADS.mkdir(parents=True, exist_ok=True)
PREFIX.mkdir(parents=True, exist_ok=True)
for formula in lock["formulae"]:
    if args.only and formula["name"] != args.only: continue
    bottle = formula["bottle"]
    archive = DOWNLOADS / (bottle["sha256"] + ".tar.gz")
    if not archive.exists() and bottle["sha256"] in existing:
        shutil.copy2(existing[bottle["sha256"]], archive)
    if not archive.exists():
        scope = "repository:homebrew/core/" + formula["name"] + ":pull"
        token_url = "https://ghcr.io/token?service=ghcr.io&scope=" + urllib.parse.quote(scope)
        token = json.load(urllib.request.urlopen(token_url))["token"]
        request = urllib.request.Request(bottle["url"], headers={"Authorization": "Bearer " + token})
        with urllib.request.urlopen(request) as response: archive.write_bytes(response.read())
    if hashlib.sha256(archive.read_bytes()).hexdigest() != bottle["sha256"]:
        raise SystemExit(f"Checksum mismatch: {archive}")
    print(f"Verified {formula['name']} {formula['version']}")
    with tarfile.open(archive) as tar:
        # All members must be confined to this formula's Cellar folder. Symlinks may only be relative.
        for member in tar.getmembers():
            p = pathlib.PurePosixPath(member.name)
            if p.is_absolute() or ".." in p.parts or not p.parts or p.parts[0] != formula["name"]:
                raise SystemExit(f"Unsafe archive path: {member.name}")
            if member.issym() or member.islnk():
                link = pathlib.PurePosixPath(member.linkname)
                resolved = pathlib.PurePosixPath(os.path.normpath(str(p.parent / link) if member.issym() else str(link)))
                if link.is_absolute() or not resolved.parts or resolved.parts[0] != formula["name"] or ".." in resolved.parts:
                    raise SystemExit("Unsafe archive link")
        tar.extractall(PREFIX / "Cellar")
    opt = PREFIX / "opt"
    opt.mkdir(exist_ok=True)
    link = opt / formula["name"]
    if not link.exists(): link.symlink_to(pathlib.Path("../Cellar") / formula["name"] / formula["version"])
print("Run: python3 Scripts/bundle-tools.py --prefix .build/toolchain")
