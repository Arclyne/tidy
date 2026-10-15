#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_directory="$project_root/build"
app_bundle="$output_directory/Tidy.app"

cd "$project_root"
xattr -cr Sources Support

swift build -c release --product Tidy
binary_directory="$(swift build -c release --show-bin-path)"

rm -rf "$app_bundle"
mkdir -p "$app_bundle/Contents/MacOS" "$app_bundle/Contents/Resources"
cp "$binary_directory/Tidy" "$app_bundle/Contents/MacOS/Tidy"
cp Support/Info.plist "$app_bundle/Contents/Info.plist"
cp Support/AppIcon.icns "$app_bundle/Contents/Resources/AppIcon.icns"
cp Sources/TidyCore/Resources/rules.json "$app_bundle/Contents/Resources/rules.json"

xattr -cr "$app_bundle"
codesign --force --sign - "$app_bundle"

if [[ "${1:-}" == "--install" ]]; then
    rm -rf /Applications/Tidy.app
    cp -R "$app_bundle" /Applications/Tidy.app
    echo "Installed /Applications/Tidy.app"
else
    echo "Built $app_bundle"
fi
