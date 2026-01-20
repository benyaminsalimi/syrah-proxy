#!/bin/bash
# Pre-commit check script for SyrahProxy
# Run this before pushing to ensure CI will pass

set -e

echo "🔍 Running static checks..."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if melos is installed
if ! command -v melos &> /dev/null; then
    echo -e "${YELLOW}Installing melos...${NC}"
    dart pub global activate melos
fi

echo ""
echo "📦 Bootstrapping packages..."
dart pub global run melos bootstrap

echo ""
echo "🔨 Running code generation..."
cd packages/syrah_core
dart run build_runner build --delete-conflicting-outputs
cd ../..

echo ""
echo "🔍 Analyzing code..."

echo "  Analyzing syrah_core..."
cd packages/syrah_core
if dart analyze --no-fatal-warnings .; then
    echo -e "${GREEN}  ✅ syrah_core analysis passed${NC}"
else
    echo -e "${RED}  ❌ syrah_core analysis failed${NC}"
    exit 1
fi
cd ../..

echo "  Analyzing syrah_app..."
cd packages/syrah_app
if flutter analyze --no-fatal-infos --no-fatal-warnings; then
    echo -e "${GREEN}  ✅ syrah_app analysis passed${NC}"
else
    echo -e "${RED}  ❌ syrah_app analysis failed${NC}"
    exit 1
fi
cd ../..

echo "  Analyzing syrah_proxy_macos..."
cd packages/syrah_proxy_macos
if flutter analyze --no-fatal-infos --no-fatal-warnings; then
    echo -e "${GREEN}  ✅ syrah_proxy_macos analysis passed${NC}"
else
    echo -e "${RED}  ❌ syrah_proxy_macos analysis failed${NC}"
    exit 1
fi
cd ../..

echo ""
echo "🧪 Running tests..."
echo "  Testing syrah_core..."
cd packages/syrah_core
if dart test; then
    echo -e "${GREEN}  ✅ syrah_core tests passed${NC}"
else
    echo -e "${RED}  ❌ syrah_core tests failed${NC}"
    exit 1
fi
cd ../..

echo "  Testing syrah_app..."
cd packages/syrah_app
if flutter test; then
    echo -e "${GREEN}  ✅ syrah_app tests passed${NC}"
else
    echo -e "${RED}  ❌ syrah_app tests failed${NC}"
    exit 1
fi
cd ../..

echo ""
echo -e "${GREEN}✅ All checks passed! Safe to push.${NC}"
