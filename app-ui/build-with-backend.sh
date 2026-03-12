#!/bin/bash

# Build script for ClassFox with embedded backend (Multi-Architecture)
# Usage: ./build-with-backend.sh

set -e

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m' # No Color

TARGETS=("aarch64-apple-darwin" "x86_64-apple-darwin")

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
echo -e "${GREEN}📦 Building Tauri frontend targets...${NC}"
cd "$SCRIPT_DIR"

if [ -f "$HOME/.cargo/env" ]; then
    # Standard rustup install layout.
    source "$HOME/.cargo/env"
else
    # Fallback for environments where rustup installed only the active toolchain.
    CARGO_BIN="$(dirname "$(rustup which cargo)")"
    export PATH="$CARGO_BIN:$PATH"
fi

for TARGET in "${TARGETS[@]}"; do
    if [ "$TARGET" = "aarch64-apple-darwin" ]; then
        ARCH="arm64"
        ARCH_LABEL="Apple Silicon (arm64)"
    else
        ARCH="x86_64"
        ARCH_LABEL="Intel (x86_64)"
    fi

    echo -e "${GREEN}🚀 Building ClassFox for ${ARCH_LABEL}...${NC}"

    # Ensure rust target is installed
    rustup target add "$TARGET"

    # Run tauri build with specific target without clearing the shared cache.
    npm run tauri build -- --target "$TARGET"

    echo -e "${GREEN}✅ Build complete for ${ARCH_LABEL}${NC}"
    echo "App bundle: src-tauri/target/${TARGET}/release/bundle/macos/课狐ClassFox.app"
    echo "DMG: src-tauri/target/${TARGET}/release/bundle/dmg/课狐ClassFox_1.2.0_${ARCH}.dmg"
    echo ""
done

echo -e "${GREEN}✅ All builds complete!${NC}"
echo "Built targets:"
echo "  - src-tauri/target/aarch64-apple-darwin/release/bundle/macos/课狐ClassFox.app"
echo "  - src-tauri/target/x86_64-apple-darwin/release/bundle/macos/课狐ClassFox.app"
echo ""
echo "Note: the embedded Python backend is still built for the current host architecture."
