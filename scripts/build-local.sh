#!/bin/bash
# Build a local development copy without installing, publishing, or using a paid identity.
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
xcodebuild -project "$PROJECT_ROOT/NotchFlow.xcodeproj" -scheme NotchFlow \
    -configuration Debug -destination 'platform=macOS' \
    -derivedDataPath "$PROJECT_ROOT/build/DerivedData" build
