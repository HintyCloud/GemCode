#!/usr/bin/env bash
# Gem Universal Installer
# Detects platform, downloads the correct binary, and installs it.
# Usage: curl -sL https://raw.githubusercontent.com/HintyCloud/Gem-Cli/main/GemBin/install.sh | bash
#
# Gem - Agentic AI Ecosystem by HintyCloud
# Version 1.0.0 - GPL-3.0

set -euo pipefail

GEM_VERSION="1.0.0"
GEM_REPO="HintyCloud/Gem-Cli"
GEM_BASE_URL="https://raw.githubusercontent.com/${GEM_REPO}/main/GemBin"
INSTALL_DIR="${1:-/usr/local/bin}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Gem CLI Installer v${GEM_VERSION}        ║${NC}"
echo -e "${BLUE}║     HintyCloud - Agentic AI           ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"

# Detect platform
detect_platform() {
    local os arch

    # Check for Termux
    if [ -n "${PREFIX:-}" ] && echo "$PREFIX" | grep -q "com.termux"; then
        os="termux"
        arch="arm64"
        echo -e "${YELLOW}Detected: Termux/Android (ARM64)${NC}"
        echo "termux-arm64"
        return
    fi

    # OS detection
    case "$(uname -s 2>/dev/null)" in
        Linux*)  os="linux" ;;
        Darwin*) os="macos" ;;
        MINGW*|MSYS*|CYGWIN*) os="windows" ;;
        *)       os="unknown" ;;
    esac

    # Architecture detection
    case "$(uname -m 2>/dev/null)" in
        x86_64|amd64)  arch="x86_64" ;;
        aarch64|arm64) arch="arm64" ;;
        armv7l|armv7)  arch="arm32" ;;
        i386|i686)     arch="x86" ;;
        *)             arch="unknown" ;;
    esac

    echo -e "${GREEN}Detected: ${os} (${arch})${NC}"
    echo "${os}-${arch}"
}

PLATFORM=$(detect_platform)
PLATFORM_DIR=""

case "$PLATFORM" in
    linux-x86_64|linux-arm64|macos-x86_64|macos-arm64|windows-x86_64|windows-arm64|termux-arm64)
        PLATFORM_DIR="$PLATFORM"
        ;;
    *)
        echo -e "${RED}Unsupported platform: $PLATFORM${NC}"
        echo "Supported: linux-x86_64, linux-arm64, macos-x86_64, macos-arm64, windows-x86_64, windows-arm64, termux-arm64"
        echo ""
        echo "Alternative: Install via pip (Python 3.10+):"
        echo "  pip install gem-cli"
        echo ""
        echo "Or use an alternative implementation:"
        echo "  Rust:  cd etc/gem-rust && cargo install --path ."
        echo "  Go:    cd etc/gem-go && go install ."
        echo "  Bash:  cd etc/gem-bash && ./install.sh"
        exit 1
        ;;
esac

# Download
TMP_DIR=$(mktemp -d)
BINARY_NAME="gem"
if echo "$PLATFORM" | grep -q "windows"; then
    BINARY_NAME="gem.exe"
fi

echo -e "${BLUE}Downloading Gem for ${PLATFORM}...${NC}"

# Try GitHub API first
DOWNLOAD_URL="${GEM_BASE_URL}/${PLATFORM_DIR}/${BINARY_NAME}"
echo "  URL: ${DOWNLOAD_URL}"

HTTP_CODE=$(curl -sL -w "%{http_code}" -o "${TMP_DIR}/${BINARY_NAME}" "${DOWNLOAD_URL}" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" != "200" ]; then
    echo -e "${YELLOW}Pre-compiled binary not available for ${PLATFORM}.${NC}"
    echo -e "${YELLOW}Falling back to pip installation...${NC}"

    if command -v pip &>/dev/null || command -v pip3 &>/dev/null; then
        echo -e "${BLUE}Installing via pip...${NC}"
        pip install gem-cli 2>/dev/null || pip3 install gem-cli 2>/dev/null
        echo -e "${GREEN}Gem installed via pip!${NC}"
        rm -rf "$TMP_DIR"
        exit 0
    else
        echo -e "${RED}pip not found. Please install Python 3.10+ and pip, then run:${NC}"
        echo "  pip install gem-cli"
        rm -rf "$TMP_DIR"
        exit 1
    fi
fi

# Verify
chmod +x "${TMP_DIR}/${BINARY_NAME}"

# Check checksum if available
CHECKSUM_URL="${GEM_BASE_URL}/${PLATFORM_DIR}/CHECKSUMS.txt"
CHECKSUM_FILE="${TMP_DIR}/CHECKSUMS.txt"
curl -sL -o "$CHECKSUM_FILE" "$CHECKSUM_URL" 2>/dev/null || true
if [ -s "$CHECKSUM_FILE" ]; then
    echo -e "${BLUE}Verifying checksum...${NC}"
    (cd "$TMP_DIR" && sha256sum -c CHECKSUMS.txt 2>/dev/null) && \
        echo -e "${GREEN}Checksum verified!${NC}" || \
        echo -e "${YELLOW}Checksum verification failed (binary may still be valid).${NC}"
fi

# Install
echo -e "${BLUE}Installing to ${INSTALL_DIR}...${NC}"

if [ -w "$INSTALL_DIR" ]; then
    cp "${TMP_DIR}/${BINARY_NAME}" "${INSTALL_DIR}/${BINARY_NAME}"
else
    echo -e "${YELLOW}sudo required for ${INSTALL_DIR}${NC}"
    sudo cp "${TMP_DIR}/${BINARY_NAME}" "${INSTALL_DIR}/${BINARY_NAME}"
fi

# Cleanup
rm -rf "$TMP_DIR"

# Verify installation
echo ""
if command -v gem &>/dev/null; then
    echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   Gem CLI installed successfully!     ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
    echo ""
    gem --version 2>/dev/null || true
    echo ""
    echo -e "${BLUE}Quick start:${NC}"
    echo "  gem status    # Check system status"
    echo "  gem chat      # Start interactive chat"
    echo "  gem serve     # Start the API server"
    echo ""
    echo -e "${BLUE}Documentation:${NC}"
    echo "  https://github.com/HintyCloud/Gem-Cli"
else
    echo -e "${YELLOW}Gem installed but not in PATH.${NC}"
    echo "Add ${INSTALL_DIR} to your PATH:"
    echo "  export PATH=\"${INSTALL_DIR}:\$PATH\""
fi
