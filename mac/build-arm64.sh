#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
QT6_DIR="${QT6_DIR:-$ROOT/../qt6/6.5.3/macos}"
OPENSSL_ROOT="${OPENSSL_ROOT:-/opt/homebrew/opt/openssl@3}"
BUILD_DIR="$ROOT/build-arm64"

if [ ! -d "$QT6_DIR" ]; then
    echo "Qt 6 not found at $QT6_DIR" >&2
    echo "Install with: python3 -m aqt install-qt mac desktop 6.5.3 clang_64 -O $ROOT/../qt6 -m qtwebengine qtwebchannel qt5compat qtpositioning" >&2
    exit 1
fi

if [ ! -f "$OPENSSL_ROOT/lib/libcrypto.3.dylib" ]; then
    echo "OpenSSL not found at $OPENSSL_ROOT" >&2
    exit 1
fi

cd "$ROOT"

if [ ! -f iina/deps/lib/libmpv.dylib ]; then
    echo "Downloading arm64 media libs via IINA..."
    (cd iina && bash other/download_libs.sh --arch arm64)
fi
(cd iina/deps/lib && ln -sf libmpv.2.dylib libmpv.dylib)

export PATH="$QT6_DIR/bin:$PATH"

STUB_FRAMEWORKS="${STUB_FRAMEWORKS:-$ROOT/../stub-frameworks}"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
(
    cd "$BUILD_DIR"
    cmake \
        -DCMAKE_OSX_ARCHITECTURES=arm64 \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_PREFIX_PATH="$QT6_DIR" \
        -DSTREMIO_USE_QT6=ON \
        -DOPENSSL_ROOT_DIR="$OPENSSL_ROOT" \
        -DOPENSSL_CRYPTO_LIBRARY="$OPENSSL_ROOT/lib/libcrypto.3.dylib" \
        -DCMAKE_EXE_LINKER_FLAGS="-F$STUB_FRAMEWORKS" \
        ..
    make -j"$(sysctl -n hw.ncpu)"
)

APP="$BUILD_DIR/stremio.app"
DEST="$APP/Contents/MacOS"
export PATH="$QT6_DIR/bin:$PATH"

cp /opt/homebrew/bin/node "$DEST/"
chmod +w "$DEST/node"
"$ROOT/mac/finalize-arm64.sh" "$APP"

echo "Built: $APP"
file "$DEST/stremio"
