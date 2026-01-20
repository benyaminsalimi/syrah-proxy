#!/bin/bash
set -e

# Syrah Android Build Script

echo "🔨 Building Syrah for Android..."

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
OUTPUT_DIR="$PROJECT_ROOT/dist/android"

echo "📦 Version: $VERSION ($BUILD_NUMBER)"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Bootstrap packages
echo "📦 Bootstrapping packages..."
melos bootstrap

# Generate code
echo "⚙️ Running code generation..."
melos run generate || true

# Navigate to app package
cd packages/netscope_app

# Build APK (release)
echo "🏗️ Building APK..."
flutter build apk --release

# Build App Bundle (for Play Store)
echo "🏗️ Building App Bundle..."
flutter build appbundle --release

# Copy artifacts to output directory
echo "📦 Copying build artifacts..."

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
AAB_PATH="build/app/outputs/bundle/release/app-release.aab"

if [ -f "$APK_PATH" ]; then
    cp "$APK_PATH" "$OUTPUT_DIR/${APP_NAME}-${VERSION}-android.apk"
    echo "✅ APK created: $OUTPUT_DIR/${APP_NAME}-${VERSION}-android.apk"
fi

if [ -f "$AAB_PATH" ]; then
    cp "$AAB_PATH" "$OUTPUT_DIR/${APP_NAME}-${VERSION}-android.aab"
    echo "✅ AAB created: $OUTPUT_DIR/${APP_NAME}-${VERSION}-android.aab"
fi

# Build split APKs for different architectures
echo "🏗️ Building split APKs..."
flutter build apk --release --split-per-abi

SPLIT_APK_DIR="build/app/outputs/flutter-apk"
for apk in "$SPLIT_APK_DIR"/app-*-release.apk; do
    if [ -f "$apk" ]; then
        filename=$(basename "$apk")
        arch=$(echo "$filename" | sed 's/app-//' | sed 's/-release.apk//')
        cp "$apk" "$OUTPUT_DIR/${APP_NAME}-${VERSION}-android-${arch}.apk"
        echo "✅ APK ($arch) created: $OUTPUT_DIR/${APP_NAME}-${VERSION}-android-${arch}.apk"
    fi
done

# Return to project root
cd "$PROJECT_ROOT"

# Print summary
echo ""
echo "================================================"
echo "✅ Android Build Complete!"
echo "================================================"
echo ""
echo "Build artifacts:"
echo ""

# List all APKs with sizes
for file in "$OUTPUT_DIR"/*.apk; do
    if [ -f "$file" ]; then
        echo "  📱 APK: $(basename "$file")"
        echo "     Size: $(du -h "$file" | cut -f1)"
    fi
done

# List AAB
for file in "$OUTPUT_DIR"/*.aab; do
    if [ -f "$file" ]; then
        echo "  📦 AAB: $(basename "$file")"
        echo "     Size: $(du -h "$file" | cut -f1)"
    fi
done

echo ""
echo "Installation:"
echo "  adb install $OUTPUT_DIR/${APP_NAME}-${VERSION}-android.apk"
echo ""
echo "For Play Store, upload the .aab file."
