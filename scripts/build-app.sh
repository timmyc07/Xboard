#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
xcodebuild -project Xboard.xcodeproj -scheme Xboard -configuration Release \
  -destination 'platform=macOS' -derivedDataPath build/DerivedData \
  ONLY_ACTIVE_ARCH=NO build
mkdir -p build
ditto build/DerivedData/Build/Products/Release/Xboard.app build/Xboard.app
ditto -c -k --keepParent build/Xboard.app build/Xboard.zip
printf 'App: %s/build/Xboard.app\nArchive: %s/build/Xboard.zip\n' "$project_dir" "$project_dir"
