#!/bin/bash
set -e

APP="PS5Streamer"
SCHEME="PS5Streamer"
BIN_DIR="PS5Streamer/Resources/Binaries"
LIBS_DIR="$BIN_DIR/libs"
BUILD_DIR="build/Release"
DMG_NAME="PS5Streamer.dmg"

echo "▶ Setting up binaries..."
mkdir -p "$BIN_DIR" "$LIBS_DIR"

# Copy binaries
cp /opt/homebrew/bin/nginx "$BIN_DIR/nginx"
cp /opt/homebrew/sbin/dnsmasq "$BIN_DIR/dnsmasq"
chmod +x "$BIN_DIR/nginx" "$BIN_DIR/dnsmasq"

# Copy nginx dylib dependencies
cp /opt/homebrew/opt/pcre2/lib/libpcre2-8.0.dylib   "$LIBS_DIR/"
cp /opt/homebrew/opt/openssl@3/lib/libssl.3.dylib    "$LIBS_DIR/"
cp /opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib "$LIBS_DIR/"

# Fix nginx to find dylibs relative to itself (@loader_path/libs/)
echo "▶ Fixing dylib paths in nginx..."
install_name_tool -change \
    /opt/homebrew/opt/pcre2/lib/libpcre2-8.0.dylib \
    @loader_path/libs/libpcre2-8.0.dylib \
    "$BIN_DIR/nginx"
install_name_tool -change \
    /opt/homebrew/opt/openssl@3/lib/libssl.3.dylib \
    @loader_path/libs/libssl.3.dylib \
    "$BIN_DIR/nginx"
install_name_tool -change \
    /opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib \
    @loader_path/libs/libcrypto.3.dylib \
    "$BIN_DIR/nginx"

# Fix libssl → libcrypto reference
install_name_tool -change \
    /opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib \
    @loader_path/libcrypto.3.dylib \
    "$LIBS_DIR/libssl.3.dylib"

echo "▶ Generating Xcode project..."
xcodegen generate

echo "▶ Building Release..."
xcodebuild \
    -project "$APP.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath build \
    clean build \
    | grep -E "error:|warning:|Build succeeded|Build FAILED"

APP_PATH="build/Build/Products/Release/$APP.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Build failed — app not found at $APP_PATH"
    exit 1
fi

echo "▶ Creating DMG..."
rm -f "$DMG_NAME"

# Create a temp folder for DMG contents
TMP_DIR=$(mktemp -d)
cp -R "$APP_PATH" "$TMP_DIR/"
ln -s /Applications "$TMP_DIR/Applications"

hdiutil create \
    -volname "PS5 Streamer" \
    -srcfolder "$TMP_DIR" \
    -ov \
    -format UDZO \
    "$DMG_NAME"

rm -rf "$TMP_DIR"

echo "✅ Done — $DMG_NAME"
