#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache"
export XDG_CACHE_HOME="$PWD/.build/cache"
swift build --disable-sandbox -c release --product Launch
bin_dir=$(swift build --disable-sandbox -c release --show-bin-path)
app="$PWD/.build/Launch.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/Launch" "$app/Contents/MacOS/Launch"
cp Resources/AppIcon.png Resources/AppIcon-dark.png "$app/Contents/Resources/"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Launch</string>
<key>CFBundleIdentifier</key><string>com.suttree.goto</string>
<key>CFBundleName</key><string>Launch</string>
<key>CFBundleDisplayName</key><string>Launch</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleIconFile</key><string>AppIcon.png</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
</dict></plist>
PLIST
codesign --force --sign - "$app"
echo "$app"
