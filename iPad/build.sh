#!/bin/bash
# Builds SakuraCord for iPadOS with xtool: ./build.sh [debug|release] [--ipa]
# Requires `xtool setup` (Darwin SDK) and, on Linux, Swift 6.4 on PATH.
set -e
cd "$(dirname "$0")"
python3 tools/sync_sources.py

# Linux filesystems are case-sensitive: the code includes <openssl/...> but the
# prebuilt framework is OpenSSL.framework, so expose its headers under that name.
sdk="$HOME/.swiftpm/swift-sdks/darwin.artifactbundle/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"
headers="$PWD/.build/artifacts/openssl-package/OpenSSL/OpenSSL.xcframework/ios-arm64/OpenSSL.framework/Headers"
if [ -d "$sdk/usr/include" ] && [ -d "$headers" ]; then ln -sfn "$headers" "$sdk/usr/include/openssl"; fi

xtool dev build -c "${1:-release}" "${2:---ipa}"
