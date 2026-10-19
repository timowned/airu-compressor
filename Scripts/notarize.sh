#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${AIRU_SIGN_IDENTITY:?Set your Developer ID Application identity}"
: "${AIRU_NOTARY_PROFILE:?Set a notarytool keychain profile}"
# Re-sign with a secure timestamp for notarization. No disabling of library validation is needed.
while IFS= read -r -d '' artifact; do
  codesign --force --options runtime --timestamp --sign "$AIRU_SIGN_IDENTITY" "$artifact"
done < <(find dist/Airu.app/Contents/Resources/Encoders/lib dist/Airu.app/Contents/Resources/Encoders/bin -type f -print0)
codesign --force --options runtime --timestamp --sign "$AIRU_SIGN_IDENTITY" dist/Airu.app/Contents/MacOS/airu-cli
python3 Scripts/update-manifest.py dist/Airu.app/Contents/Resources/Encoders
codesign --force --options runtime --timestamp --sign "$AIRU_SIGN_IDENTITY" dist/Airu.app
ditto -c -k --keepParent dist/Airu.app dist/Airu-notarize.zip
xcrun notarytool submit dist/Airu-notarize.zip --keychain-profile "$AIRU_NOTARY_PROFILE" --wait
xcrun stapler staple dist/Airu.app
xcrun stapler validate dist/Airu.app
