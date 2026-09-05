#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache"
export XDG_CACHE_HOME="$PWD/.build/cache"
swift build --disable-sandbox -c release --product Menu
bin_dir=$(swift build --disable-sandbox -c release --show-bin-path)
app="$PWD/.build/Menu.app"
mkdir -p "$app/Contents/MacOS"
cp "$bin_dir/Menu" "$app/Contents/MacOS/Menu"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Menu</string>
<key>CFBundleIdentifier</key><string>com.suttree.menu</string>
<key>CFBundleName</key><string>Menu</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$app"
echo "$app"
