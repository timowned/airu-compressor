#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build --package-path Packages/AiruUI --scratch-path .build/ui-tests
airu_ui_bin="$(swift build --package-path Packages/AiruUI --scratch-path .build/ui-tests --show-bin-path)"
# SwiftPM copies raw catalogs; compile them before using ImageRenderer outside Xcode.
xcrun actool Packages/AiruUI/Sources/AiruUI/Resources/Assets.xcassets \
  --compile "$airu_ui_bin/AiruUI_AiruUI.bundle" --platform macosx --minimum-deployment-target 14.0
AIRU_RENDER_UI=1 swift test --package-path Packages/AiruUI --scratch-path .build/ui-tests \
  --filter 'renderImportAnalysisReference|renderDropEdgeReference'
