#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build
swift test --package-path Packages/AiruCore --scratch-path .build/core-tests
swift test --package-path Packages/AiruUI --scratch-path .build/ui-tests
python3 Scripts/test-cli.py
