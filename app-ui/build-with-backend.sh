#!/bin/bash

# Build script for ClassFox with embedded backend (Multi-Architecture)
# Usage: ./build-with-backend.sh [x86_64|arm64]

set -e

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Detect architecture
ARCH=${1:-$(uname -m)}
if [ "$ARCH" == "arm64" ] || [ "$ARCH" == "aarch64" ]; then
    TARGET="aarch64-apple-darwin"
    ARCH_LABEL="Apple Silicon (arm64)"
else
    TARGET="x86_64-apple-darwin"
    ARCH_LABEL="Intel (x86_64)"
fi

echo -e "${GREEN}🚀 Building ClassFox for ${ARCH_LABEL}...${NC}"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Build backend first
echo -e "${GREEN}📦 Building Python backend...${NC}"
cd "$SCRIPT_DIR/../api-service"
rm -rf dist build
# PyInstaller will build for the host architecture by default
CC=clang CXX=clang++ uv run pyinstaller backend.spec --noconfirm

# Copy platform-specific binary for potential externalBin use (though we use resources)
cp dist/class-assistant-backend "dist/class-assistant-backend-$TARGET"

# Copy backend for Tauri resources
echo -e "${GREEN}📋 Preparing backend for Tauri...${NC}"
mkdir -p "$SCRIPT_DIR/src-tauri/backend"
rm -rf "$SCRIPT_DIR/src-tauri/backend/*"
cp dist/class-assistant-backend "$SCRIPT_DIR/src-tauri/backend/"
cp .env.example "$SCRIPT_DIR/src-tauri/backend/"
chmod +x "$SCRIPT_DIR/src-tauri/backend/class-assistant-backend"

# Build Tauri app
echo -e "${GREEN}📦 Building Tauri frontend (${TARGET})...${NC}"
cd "$SCRIPT_DIR"
source "$HOME/.cargo/env"

# Ensure rust target is installed
rustup target add "$TARGET"

# Run tauri build with specific target
npm run tauri build -- --target "$TARGET"

echo -e "${GREEN}✅ Build complete!${NC}"
echo "Architecture: ${ARCH_LABEL}"
echo "App bundle: src-tauri/target/${TARGET}/release/bundle/macos/课狐ClassFox.app"
echo "DMG: src-tauri/target/${TARGET}/release/bundle/dmg/课狐ClassFox_1.2.0_${ARCH}.dmg"
