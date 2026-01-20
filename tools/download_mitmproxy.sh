#!/bin/bash
# Download mitmproxy standalone binaries for bundling with Syrah app

set -e

VERSION="12.2.1"
BASE_URL="https://downloads.mitmproxy.org/${VERSION}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DOWNLOAD_DIR="${PROJECT_ROOT}/tools/mitmproxy_binaries"

mkdir -p "$DOWNLOAD_DIR"

echo "Downloading mitmproxy ${VERSION} binaries..."

# Detect current platform
PLATFORM=$(uname -s)
ARCH=$(uname -m)

download_and_extract() {
    local filename=$1
    local url="${BASE_URL}/${filename}"
    local dest="${DOWNLOAD_DIR}/${filename}"

    echo "Downloading: $url"

    if [ -f "$dest" ]; then
        echo "  Already exists, skipping..."
    else
        curl -L -o "$dest" "$url"
    fi

    # Extract based on file type
    if [[ "$filename" == *.tar.gz ]]; then
        echo "Extracting $filename..."
        tar -xzf "$dest" -C "$DOWNLOAD_DIR"
    elif [[ "$filename" == *.zip ]]; then
        echo "Extracting $filename..."
        unzip -o "$dest" -d "$DOWNLOAD_DIR"
    fi
}

# Download for current platform
case "$PLATFORM" in
    Darwin)
        if [ "$ARCH" = "arm64" ]; then
            download_and_extract "mitmproxy-${VERSION}-macos-arm64.tar.gz"
            MITMDUMP_PATH="${DOWNLOAD_DIR}/mitmdump"
        else
            download_and_extract "mitmproxy-${VERSION}-macos-x86_64.tar.gz"
            MITMDUMP_PATH="${DOWNLOAD_DIR}/mitmdump"
        fi
        ;;
    Linux)
        download_and_extract "mitmproxy-${VERSION}-linux-x86_64.tar.gz"
        MITMDUMP_PATH="${DOWNLOAD_DIR}/mitmdump"
        ;;
    MINGW*|MSYS*|CYGWIN*)
        download_and_extract "mitmproxy-${VERSION}-windows-x64.zip"
        MITMDUMP_PATH="${DOWNLOAD_DIR}/mitmdump.exe"
        ;;
    *)
        echo "Unknown platform: $PLATFORM"
        exit 1
        ;;
esac

# Copy to app resources
MACOS_RESOURCES="${PROJECT_ROOT}/packages/syrah_app/macos/Runner/Resources"
mkdir -p "$MACOS_RESOURCES"

if [ -f "$MITMDUMP_PATH" ]; then
    echo "Copying mitmdump to macOS resources..."
    cp "$MITMDUMP_PATH" "$MACOS_RESOURCES/"
    chmod +x "$MACOS_RESOURCES/mitmdump"
    echo "  -> $MACOS_RESOURCES/mitmdump"
fi

# Copy syrah_bridge addon
BRIDGE_SRC="${PROJECT_ROOT}/packages/syrah_bridge/syrah_bridge.py"
if [ -f "$BRIDGE_SRC" ]; then
    echo "Copying syrah_bridge.py to resources..."
    cp "$BRIDGE_SRC" "$MACOS_RESOURCES/"
    echo "  -> $MACOS_RESOURCES/syrah_bridge.py"
fi

echo ""
echo "Done! mitmproxy binaries are ready."
echo ""
echo "Files in $DOWNLOAD_DIR:"
ls -la "$DOWNLOAD_DIR"
echo ""
echo "Files in macOS Resources:"
ls -la "$MACOS_RESOURCES"
