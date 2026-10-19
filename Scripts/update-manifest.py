#!/usr/bin/env python3
"""Refresh Mach-O hashes after code signing, before signing the containing app."""
import hashlib, json, pathlib, sys
root = pathlib.Path(sys.argv[1])
path = root / "manifest.json"
manifest = json.loads(path.read_text())
for name in manifest["sha256"]:
    manifest["sha256"][name] = hashlib.sha256((root / name).read_bytes()).hexdigest()
path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
