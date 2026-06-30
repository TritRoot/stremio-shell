#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
QT6_DIR="${QT6_DIR:-$ROOT/../qt6/6.5.3/macos}"
OPENSSL_ROOT="${OPENSSL_ROOT:-/opt/homebrew/opt/openssl@3}"
STUB_FRAMEWORKS="${STUB_FRAMEWORKS:-$ROOT/../stub-frameworks}"
APP="${1:-$ROOT/build-arm64/stremio.app}"
DEST="$APP/Contents/MacOS"
FW="$APP/Contents/Frameworks"

if [ ! -d "$APP" ]; then
    echo "App bundle not found: $APP" >&2
    exit 1
fi

export PATH="$QT6_DIR/bin:$PATH"

cp /opt/homebrew/bin/node "$DEST/"
chmod +w "$DEST/node"

# Deploy Qt frameworks, plugins, and QML imports used by main.qml
macdeployqt "$APP" \
    -qmldir="$ROOT" \
    -executable="$DEST/node"

mkdir -p "$FW"
cp "$ROOT/iina/deps/lib/"*.dylib "$FW/"
ln -sf libmpv.2.dylib "$FW/libmpv.dylib"
cp "$OPENSSL_ROOT/lib/libcrypto.3.dylib" "$FW/"
install_name_tool -id @rpath/libcrypto.3.dylib "$FW/libcrypto.3.dylib"
cp -R "$STUB_FRAMEWORKS/AGL.framework" "$FW/"

# Sign Mach-O dependencies before the main binary (server.js must not be in MacOS yet)
find "$APP/Contents/Frameworks" "$APP/Contents/PlugIns" -type f 2>/dev/null | while read -r f; do
    file "$f" | grep -q 'Mach-O' || continue
    codesign --force --sign - "$f" 2>/dev/null || true
done
codesign --force --sign - "$FW/QtWebEngineCore.framework/Versions/A/Helpers/QtWebEngineProcess.app/Contents/MacOS/QtWebEngineProcess" 2>/dev/null || true
codesign --force --sign - "$FW/AGL.framework" 2>/dev/null || true
codesign --force --entitlements "$ROOT/mac/entitlements.plist" --sign - "$DEST/stremio"

if [ -f "$ROOT/build/stremio.app/Contents/MacOS/server.js" ]; then
    cp "$ROOT/build/stremio.app/Contents/MacOS/server.js" "$DEST/"
fi

echo "Finalized: $APP"
ls "$APP/Contents/Resources/qml" 2>/dev/null | head -10 || echo "WARNING: no QML resources deployed"
