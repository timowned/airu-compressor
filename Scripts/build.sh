#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ ! -f Resources/Encoders/manifest.json ]]; then
  echo "Bundle tools first: python3 Scripts/fetch-tools.py && python3 Scripts/bundle-tools.py --prefix .build/toolchain" >&2
  exit 1
fi
if [[ ! -f Resources/Upscaler/manifest.json || ! -f Resources/Upscaler/models/realesrgan-x4plus.bin ]]; then
  echo "Bundle Real-ESRGAN first: python3 Scripts/bundle-upscaler.py" >&2
  exit 1
fi
swift Scripts/generate-icon.swift --generate
swift build -c release --arch arm64
airu_cli_bin="$(swift build -c release --arch arm64 --show-bin-path)"
xcodebuild -project Airu.xcodeproj -scheme Airu -configuration Release -derivedDataPath .build/xcode \
  ARCHS=arm64 CODE_SIGNING_ALLOWED=NO build
mkdir -p dist
ditto .build/xcode/Build/Products/Release/Airu.app dist/Airu.app
ditto Resources/Encoders dist/Airu.app/Contents/Resources/Encoders
ditto Resources/Upscaler dist/Airu.app/Contents/Resources/Upscaler
cp "$airu_cli_bin/airu" dist/Airu.app/Contents/MacOS/airu-cli
# Retain actool's system-facing AppIcon and package the full-resolution Dock family separately.
swift Scripts/generate-icon.swift --package dist/Airu.app
identity="${AIRU_SIGN_IDENTITY:--}"
signing_options=(--options 0)
if [[ "$identity" != "-" ]]; then signing_options=(--options runtime); fi
while IFS= read -r -d '' artifact; do
  codesign --force "${signing_options[@]}" --timestamp=none --sign "$identity" "$artifact"
done < <(find dist/Airu.app/Contents/Resources/Encoders/lib dist/Airu.app/Contents/Resources/Encoders/bin -type f -print0)
codesign --force "${signing_options[@]}" --timestamp=none --sign "$identity" dist/Airu.app/Contents/Resources/Upscaler/bin/realesrgan-ncnn-vulkan
python3 Scripts/update-manifest.py dist/Airu.app/Contents/Resources/Upscaler
codesign --force "${signing_options[@]}" --timestamp=none --sign "$identity" dist/Airu.app/Contents/MacOS/airu-cli
python3 Scripts/update-manifest.py dist/Airu.app/Contents/Resources/Encoders
codesign --force "${signing_options[@]}" --timestamp=none --sign "$identity" dist/Airu.app
codesign --verify --deep --strict dist/Airu.app
echo "Built dist/Airu.app (arm64, bundled minimum macOS 27.0)"
