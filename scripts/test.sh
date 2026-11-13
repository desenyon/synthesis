#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
export EDITOR=vim VISUAL=vim GIT_EDITOR=vim
synthesis_sdk="$(xcode-select -p)/SDKs/MacOSX26.5.sdk"
if [[ ! -d "$synthesis_sdk" ]]; then synthesis_sdk="$(xcrun --show-sdk-path)"; fi
developer_dir=$(xcode-select -p)
frameworks="$developer_dir/Library/Developer/Frameworks"
plugin="$developer_dir/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
if [[ -d "$frameworks/Testing.framework" && -f "$plugin" ]]; then
 swift test --build-system native --sdk "$synthesis_sdk" -Xswiftc -F -Xswiftc "$frameworks" -Xswiftc -load-plugin-library -Xswiftc "$plugin" -Xlinker -rpath -Xlinker "$frameworks" "$@"
else
 swift test --build-system native --sdk "$synthesis_sdk" "$@"
fi
