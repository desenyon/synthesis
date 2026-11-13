#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
export EDITOR=vim VISUAL=vim GIT_EDITOR=vim
synthesis_sdk="$(xcode-select -p)/SDKs/MacOSX26.5.sdk"
if [[ ! -d "$synthesis_sdk" ]]; then synthesis_sdk="$(xcrun --show-sdk-path)"; fi
synthesis_configuration="${1:-debug}"
swift build --build-system native --sdk "$synthesis_sdk" -c "$synthesis_configuration"
synthesis_bin="$(swift build --build-system native --sdk "$synthesis_sdk" -c "$synthesis_configuration" --show-bin-path)"
app="dist/Synthesis.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$synthesis_bin/Synthesis" "$app/Contents/MacOS/Synthesis"
cp -R Sources/SynthesisCore/Migrations "$app/Contents/Resources/"
cp -R Sources/SynthesisUI/Assets "$app/Contents/Resources/"
rm -rf "$app/Contents/Resources/CanvasBundle"
cp -R Sources/SynthesisUI/CanvasBundle "$app/Contents/Resources/"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleIdentifier</key><string>dev.desenyon.synthesis</string><key>CFBundleName</key><string>Synthesis</string><key>CFBundleDisplayName</key><string>Synthesis</string><key>CFBundleExecutable</key><string>Synthesis</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleShortVersionString</key><string>0.1.0</string><key>CFBundleVersion</key><string>1</string><key>LSMinimumSystemVersion</key><string>14.0</string><key>NSHighResolutionCapable</key><true/></dict></plist>
PLIST
codesign --force --deep --sign - "$app"
print "Built $app (development, ad-hoc signed; not a release)."
