#!/usr/bin/env python3
"""Bundle the pinned official universal Real-ESRGAN release as a native arm64 helper.
Development only; the installed app runs completely offline.
"""
import hashlib, json, pathlib, shutil, subprocess, urllib.request, zipfile
root = pathlib.Path(__file__).resolve().parent.parent
archive = root / '.build/upscaler/upstream.zip'
url = 'https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-macos.zip'
checksum = 'e0ad05580abfeb25f8d8fb55aaf7bedf552c375b5b4d9bd3c8d59764d2cc333a'
archive.parent.mkdir(parents=True, exist_ok=True)
if not archive.exists():
    partial = archive.with_suffix('.download')
    urllib.request.urlretrieve(url, partial)
    partial.replace(archive)
if hashlib.sha256(archive.read_bytes()).hexdigest() != checksum:
    raise SystemExit('Real-ESRGAN archive checksum mismatch; remove .build/upscaler/upstream.zip and retry')
dest = root / 'Resources/Upscaler'
with zipfile.ZipFile(archive) as source:
    for name in ['realesrgan-ncnn-vulkan', 'models/realesrgan-x4plus.bin', 'models/realesrgan-x4plus.param']:
        target = dest / ('bin/' + name if '/' not in name else name)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(source.read(name))
binary = dest / 'bin/realesrgan-ncnn-vulkan'
thin = binary.with_suffix('.arm64')
subprocess.run(['lipo', '-thin', 'arm64', str(binary), '-output', str(thin)], check=True)
thin.replace(binary); binary.chmod(0o755)
subprocess.run(['codesign', '--force', '--sign', '-', str(binary)], check=True)
files = ['bin/realesrgan-ncnn-vulkan', 'models/realesrgan-x4plus.bin', 'models/realesrgan-x4plus.param']
manifest = dict(version='20220424', model='realesrgan-x4plus', source=url, archiveSHA256=checksum,
                sha256={name: hashlib.sha256((dest / name).read_bytes()).hexdigest() for name in files})
(dest / 'manifest.json').write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n')
print('Bundled native arm64 Real-ESRGAN and x4plus weights')
