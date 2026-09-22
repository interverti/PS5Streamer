#!/bin/bash

APP="PS5Streamer"
SCHEME="PS5Streamer"
SRC_BIN="PS5Streamer/Resources/Binaries"
SRC_LIBS="$SRC_BIN/libs"
DMG_NAME="PS5Streamer.dmg"
APP_PATH="build/Build/Products/Release/$APP.app"
DEST_BIN="$APP_PATH/Contents/Resources/Binaries"

# ── Source binaries ───────────────────────────────────────────────────────────
echo "▶ Setting up source binaries..."
mkdir -p "$SRC_BIN" "$SRC_LIBS"

if [ -f /opt/homebrew/bin/nginx ]; then
    echo "  Copying from brew..."
    cp /opt/homebrew/bin/nginx    "$SRC_BIN/nginx"
    cp /opt/homebrew/sbin/dnsmasq "$SRC_BIN/dnsmasq"
    chmod +x "$SRC_BIN/nginx" "$SRC_BIN/dnsmasq"

    cp /opt/homebrew/opt/pcre2/lib/libpcre2-8.0.dylib   "$SRC_LIBS/"
    cp /opt/homebrew/opt/openssl@3/lib/libssl.3.dylib    "$SRC_LIBS/"
    cp /opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib "$SRC_LIBS/"

    echo "  Fixing dylib paths..."
    install_name_tool -change /opt/homebrew/opt/pcre2/lib/libpcre2-8.0.dylib    @loader_path/libs/libpcre2-8.0.dylib  "$SRC_BIN/nginx"
    install_name_tool -change /opt/homebrew/opt/openssl@3/lib/libssl.3.dylib    @loader_path/libs/libssl.3.dylib      "$SRC_BIN/nginx"
    install_name_tool -change /opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib @loader_path/libs/libcrypto.3.dylib   "$SRC_BIN/nginx"
    install_name_tool -change /opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib @loader_path/libcrypto.3.dylib        "$SRC_LIBS/libssl.3.dylib"
elif [ -f "$SRC_BIN/nginx" ]; then
    echo "  Using cached binaries"
else
    echo "❌ nginx not found. Install: brew tap denji/nginx && brew install nginx-full"
    exit 1
fi

# ── Xcode project ─────────────────────────────────────────────────────────────
echo "▶ Generating Xcode project..."
xcodegen generate

# ── Build ─────────────────────────────────────────────────────────────────────
echo "▶ Building Release..."
rm -rf build/Build

xcodebuild \
    -project "$APP.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath build \
    build > /tmp/ps5-build.log 2>&1

if grep -q "BUILD SUCCEEDED" /tmp/ps5-build.log; then
    echo "  ✅ Build succeeded"
else
    grep "error:" /tmp/ps5-build.log | grep -v "^/" | head -5
    echo "❌ Build failed"
    exit 1
fi

# ── Copy binaries into bundle (Xcode strips executables from resources) ───────
echo "▶ Copying binaries into bundle..."
mkdir -p "$DEST_BIN/libs"
cp "$SRC_BIN/nginx"                "$DEST_BIN/nginx"
cp "$SRC_BIN/dnsmasq"              "$DEST_BIN/dnsmasq"
cp "$SRC_LIBS/libpcre2-8.0.dylib"  "$DEST_BIN/libs/"
cp "$SRC_LIBS/libssl.3.dylib"      "$DEST_BIN/libs/"
cp "$SRC_LIBS/libcrypto.3.dylib"   "$DEST_BIN/libs/"
chmod +x "$DEST_BIN/nginx" "$DEST_BIN/dnsmasq"
echo "  ✅ Binaries bundled"

# ── DMG ───────────────────────────────────────────────────────────────────────
echo "▶ Creating DMG..."
rm -f "$DMG_NAME"

TMP_DIR=$(mktemp -d)
cp -R "$APP_PATH" "$TMP_DIR/"
ln -s /Applications "$TMP_DIR/Applications"

hdiutil create \
    -volname "PS5 Streamer" \
    -srcfolder "$TMP_DIR" \
    -ov -format UDZO \
    "$DMG_NAME" > /dev/null

rm -rf "$TMP_DIR"
echo "✅ Done — $DMG_NAME ($(du -sh "$DMG_NAME" | cut -f1))"
