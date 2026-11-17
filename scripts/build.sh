#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
export EDITOR=vim VISUAL=vim GIT_EDITOR=vim
synthesis_sdk="$(xcode-select -p)/SDKs/MacOSX26.5.sdk"
if [[ ! -d "$synthesis_sdk" ]]; then synthesis_sdk="$(xcrun --show-sdk-path)"; fi
synthesis_configuration="${1:-debug}"
swift build --build-system native --sdk "$synthesis_sdk" -c "$synthesis_configuration" --jobs "${SYNTHESIS_BUILD_JOBS:-2}"
synthesis_bin="$(swift build --build-system native --sdk "$synthesis_sdk" -c "$synthesis_configuration" --show-bin-path)"
app="${2:-${SYNTHESIS_APP_BUNDLE:-dist/Synthesis.app}}"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$synthesis_bin/Synthesis" "$app/Contents/MacOS/Synthesis"
cp -R Sources/SynthesisCore/Migrations "$app/Contents/Resources/"
rm -rf "$app/Contents/Resources/Assets"
cp -R Sources/SynthesisUI/Assets "$app/Contents/Resources/"
rm -rf "$app/Contents/Resources/CanvasBundle"
cp -R Sources/SynthesisUI/CanvasBundle "$app/Contents/Resources/"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleIdentifier</key><string>dev.desenyon.synthesis</string><key>CFBundleName</key><string>Synthesis</string><key>CFBundleDisplayName</key><string>Synthesis</string><key>CFBundleExecutable</key><string>Synthesis</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleShortVersionString</key><string>0.0.2</string><key>CFBundleVersion</key><string>2</string><key>LSMinimumSystemVersion</key><string>14.0</string><key>NSHighResolutionCapable</key><true/><key>CFBundleDocumentTypes</key><array><dict><key>CFBundleTypeName</key><string>Synthesis World</string><key>CFBundleTypeRole</key><string>Viewer</string><key>LSHandlerRank</key><string>Owner</string><key>LSItemContentTypes</key><array><string>dev.desenyon.synthesis.world</string></array></dict></array><key>UTExportedTypeDeclarations</key><array><dict><key>UTTypeIdentifier</key><string>dev.desenyon.synthesis.world</string><key>UTTypeDescription</key><string>Synthesis World</string><key>UTTypeConformsTo</key><array><string>public.data</string><string>public.content</string></array><key>UTTypeTagSpecification</key><dict><key>public.filename-extension</key><array><string>synthesis</string></array></dict></dict></array></dict></plist>
PLIST
codesign --force --deep --sign - "$app"
print "Built $app (ad-hoc signed development build)."
