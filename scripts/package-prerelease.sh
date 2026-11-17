#!/bin/zsh
# Package the already-checked native bundle. Publishing is a separate, explicit action.
set -euo pipefail
cd "${0:A:h:h}"
app="dist/Synthesis.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
architecture="$(lipo -archs "$app/Contents/MacOS/Synthesis")"
[[ "$architecture" == arm64 ]] || { print -u2 'Expected the checked Apple Silicon bundle'; exit 1; }
codesign --verify --deep --strict "$app"
folder="dist/prerelease-$version"
mkdir -p "$folder"
archive="$folder/Synthesis-$version-macos-arm64.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
cp THIRD_PARTY.md "$folder/THIRD_PARTY.md"
(cd "$folder" && shasum -a 256 "${archive:t}" > SHA256SUMS.txt)
print "Packaged $archive (ad-hoc signed, not notarized)."
