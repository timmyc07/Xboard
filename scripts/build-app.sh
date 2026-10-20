#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
xcodebuild -project OptionV.xcodeproj -scheme OptionV -configuration Release \
  -destination 'platform=macOS' -derivedDataPath build/DerivedData \
  ONLY_ACTIVE_ARCH=NO build
mkdir -p build
ditto build/DerivedData/Build/Products/Release/OptionV.app build/OptionV.app
ditto -c -k --keepParent build/OptionV.app build/OptionV.zip
printf 'App: %s/build/OptionV.app\nArchive: %s/build/OptionV.zip\n' "$project_dir" "$project_dir"
