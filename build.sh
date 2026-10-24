#!/bin/bash
set -e

APP_NAME="ProfileSwitcher"
BUILD_DIR="$(cd "$(dirname "$0")" && pwd)/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)/Sources"

echo "🔨 Building $APP_NAME..."

# Clean
rm -rf "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Compile
echo "  Compiling Swift sources..."
swiftc \
    -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
    -target arm64-apple-macos14.0 \
    -framework AppKit \
    -framework SwiftUI \
    -framework Foundation \
    "$SRC_DIR"/*.swift

# Copy Info.plist
cp "$(dirname "$0")/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Create icon if it exists
if [ -f "$(dirname "$0")/AppIcon.icns" ]; then
    cp "$(dirname "$0")/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

# Ad-hoc sign
echo "  Signing (ad-hoc)..."
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true

echo "✅ Built: $APP_BUNDLE"
echo ""
echo "To install:  cp -R \"$APP_BUNDLE\" /Applications/"
echo "To run:      open \"$APP_BUNDLE\""
