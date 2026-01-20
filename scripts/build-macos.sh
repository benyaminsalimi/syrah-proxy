#!/bin/bash
set -e

# Syrah macOS Build Script

echo "🔨 Building Syrah for macOS..."

# Navigate to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Check for required tools
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter SDK."
    exit 1
fi

if ! command -v melos &> /dev/null; then
    echo "📦 Installing melos..."
    dart pub global activate melos
fi

# Configuration
APP_NAME="Syrah"
VERSION=$(grep 'version:' packages/netscope_app/pubspec.yaml | head -1 | awk '{print $2}' | cut -d'+' -f1)
BUILD_NUMBER=$(grep 'version:' packages/netscope_app/pubspec.yaml | head -1 | awk '{print $2}' | cut -d'+' -f2)
BUILD_DIR="$PROJECT_ROOT/build/macos"
OUTPUT_DIR="$PROJECT_ROOT/dist/macos"

echo "📦 Version: $VERSION ($BUILD_NUMBER)"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf "$BUILD_DIR"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Bootstrap packages
echo "📦 Bootstrapping packages..."
melos bootstrap

# Generate code
echo "⚙️ Running code generation..."
melos run generate || true

# Build macOS app
echo "🏗️ Building macOS application..."
cd packages/netscope_app
flutter build macos --release

# Create DMG
echo "📀 Creating DMG installer..."
APP_PATH="$PROJECT_ROOT/packages/netscope_app/build/macos/Build/Products/Release/netscope_app.app"
DMG_NAME="${APP_NAME}-${VERSION}-macos.dmg"

if [ -d "$APP_PATH" ]; then
    # Create a temporary directory for DMG contents
    DMG_TEMP="$BUILD_DIR/dmg-temp"
    mkdir -p "$DMG_TEMP"

    # Copy app to temp directory
    cp -R "$APP_PATH" "$DMG_TEMP/${APP_NAME}.app"

    # Create Applications symlink
    ln -s /Applications "$DMG_TEMP/Applications"

    # Create DMG
    hdiutil create -volname "$APP_NAME" \
        -srcfolder "$DMG_TEMP" \
        -ov \
        -format UDZO \
        "$OUTPUT_DIR/$DMG_NAME"

    # Cleanup
    rm -rf "$DMG_TEMP"

    echo "✅ DMG created: $OUTPUT_DIR/$DMG_NAME"
else
    echo "⚠️ App bundle not found, skipping DMG creation"
fi

# Also create a ZIP for direct distribution
echo "📦 Creating ZIP archive..."
cd "$PROJECT_ROOT/packages/netscope_app/build/macos/Build/Products/Release"
if [ -d "netscope_app.app" ]; then
    zip -r "$OUTPUT_DIR/${APP_NAME}-${VERSION}-macos.zip" "netscope_app.app"
    echo "✅ ZIP created: $OUTPUT_DIR/${APP_NAME}-${VERSION}-macos.zip"
fi

# Return to project root
cd "$PROJECT_ROOT"

# Print summary
echo ""
echo "================================================"
echo "✅ macOS Build Complete!"
echo "================================================"
echo ""
echo "Build artifacts:"
if [ -f "$OUTPUT_DIR/$DMG_NAME" ]; then
    echo "  📀 DMG: $OUTPUT_DIR/$DMG_NAME"
    echo "     Size: $(du -h "$OUTPUT_DIR/$DMG_NAME" | cut -f1)"
fi
if [ -f "$OUTPUT_DIR/${APP_NAME}-${VERSION}-macos.zip" ]; then
    echo "  📦 ZIP: $OUTPUT_DIR/${APP_NAME}-${VERSION}-macos.zip"
    echo "     Size: $(du -h "$OUTPUT_DIR/${APP_NAME}-${VERSION}-macos.zip" | cut -f1)"
fi
echo ""
echo "To install, open the DMG and drag Syrah to Applications."
