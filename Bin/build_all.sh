#!/usr/bin/env bash
# Gem Multi-Platform Build Script
# Builds all Gem implementations and packages them into GemBin/
#
# Usage:
#   ./build_all.sh              # Build everything
#   ./build_all.sh python       # Build only Python binary
#   ./build_all.sh rust         # Build only Rust
#   ./build_all.sh go           # Build only Go
#   ./build_all.sh node         # Build only Node.js
#   ./build_all.sh c            # Build only C
#   ./build_all.sh all-langs    # Build all alternative languages
#   ./build_all.sh package      # Package everything into tarballs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GEMBIN_DIR="${SCRIPT_DIR}"
VERSION="1.0.0"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail()  { echo -e "${RED}[FAIL]${NC} $*"; exit 1; }

# --- Python (PyInstaller) ---
build_python() {
    info "Building Python binary (Linux x86_64)..."
    local outdir="${GEMBIN_DIR}/linux-x86_64"
    mkdir -p "$outdir"

    if command -v pyinstaller &>/dev/null; then
        pyinstaller --clean --noconfirm \
            --distpath "$outdir" \
            --workpath "/tmp/gem-build-work" \
            /home/z/my-project/scripts/gem_linux.spec
        
        # Generate checksum
        if [ -f "${outdir}/gem" ]; then
            (cd "$outdir" && sha256sum gem > CHECKSUMS.txt)
            ok "Python binary built: $(ls -lh "${outdir}/gem" | awk '{print $5}')"
        else
            warn "Python binary not found after build"
        fi
    else
        warn "PyInstaller not found. Install: pip install pyinstaller"
    fi
}

# --- Rust ---
build_rust() {
    info "Building Rust implementation..."
    local src="${GEMBIN_DIR}/etc/gem-rust"
    local outdir="${GEMBIN_DIR}/linux-x86_64"

    if [ -f "${src}/Cargo.toml" ]; then
        (cd "$src" && cargo build --release 2>/dev/null)
        if [ -f "${src}/target/release/gem" ]; then
            cp "${src}/target/release/gem" "${outdir}/gem-rust"
            ok "Rust binary built: $(ls -lh "${src}/target/release/gem" | awk '{print $5}')"
        fi
    else
        warn "Rust source not found at ${src}"
    fi
}

# --- Go ---
build_go() {
    info "Building Go implementation..."
    local src="${GEMBIN_DIR}/etc/gem-go"
    
    if [ -f "${src}/go.mod" ] && command -v go &>/dev/null; then
        (cd "$src" && go mod tidy && go build -o gem .)
        if [ -f "${src}/gem" ]; then
            ok "Go binary built: $(ls -lh "${src}/gem" | awk '{print $5}')"
            # Cross-compile all platforms
            info "Cross-compiling Go for all platforms..."
            (cd "$src" && \
                GOOS=linux   GOARCH=amd64 go build -o gem-linux-amd64 . && \
                GOOS=linux   GOARCH=arm64 go build -o gem-linux-arm64 . && \
                GOOS=darwin  GOARCH=amd64 go build -o gem-macos-amd64 . && \
                GOOS=darwin  GOARCH=arm64 go build -o gem-macos-arm64 . && \
                GOOS=windows GOARCH=amd64 go build -o gem-windows-amd64.exe .) && \
                ok "Go cross-compilation complete" || \
                warn "Go cross-compilation had errors"
        fi
    else
        warn "Go not found or source missing"
    fi
}

# --- Node.js ---
build_node() {
    info "Building Node.js implementation..."
    local src="${GEMBIN_DIR}/etc/gem-node"
    
    if [ -f "${src}/package.json" ]; then
        (cd "$src" && npm install --silent && npm run build 2>/dev/null) && \
            ok "Node.js build complete" || \
            warn "Node.js build had issues"
    else
        warn "Node.js source not found"
    fi
}

# --- C ---
build_c() {
    info "Building C implementation..."
    local src="${GEMBIN_DIR}/etc/gem-c"
    
    if [ -f "${src}/Makefile" ]; then
        (cd "$src" && make release)
        if [ -f "${src}/build/gem" ]; then
            ok "C binary built: $(ls -lh "${src}/build/gem" | awk '{print $5}')"
        fi
    else
        warn "C source not found"
    fi
}

# --- Java ---
build_java() {
    info "Building Java implementation..."
    local src="${GEMBIN_DIR}/etc/gem-java"
    
    if [ -f "${src}/pom.xml" ] && command -v mvn &>/dev/null; then
        (cd "$src" && mvn -q clean package)
        ok "Java build complete" || warn "Java build had issues"
    else
        warn "Maven not found or source missing"
    fi
}

# --- Package ---
package_all() {
    info "Packaging GemBin..."
    local pkgdir="${GEMBIN_DIR}/../packages"
    mkdir -p "$pkgdir"

    # Main package
    tar -czf "${pkgdir}/GemBin-${VERSION}.tar.gz" -C "$(dirname "$GEMBIN_DIR")" GemBin/
    ok "Main package: GemBin-${VERSION}.tar.gz"

    # Per-platform
    for dir in "${GEMBIN_DIR}"/linux-* "${GEMBIN_DIR}"/windows-* "${GEMBIN_DIR}"/macos-* "${GEMBIN_DIR}"/termux-*; do
        if [ -d "$dir" ]; then
            plat=$(basename "$dir")
            tar -czf "${pkgdir}/Gem-${plat}-${VERSION}.tar.gz" -C "$GEMBIN_DIR" "$plat/"
            ok "Platform package: Gem-${plat}-${VERSION}.tar.gz"
        fi
    done

    # Per-language
    for dir in "${GEMBIN_DIR}"/etc/gem-*; do
        if [ -d "$dir" ]; then
            lang=$(basename "$dir")
            tar -czf "${pkgdir}/Gem-${lang}-${VERSION}.tar.gz" -C "${GEMBIN_DIR}/etc" "$lang/"
            ok "Language package: Gem-${lang}-${VERSION}.tar.gz"
        fi
    done

    ok "All packages created in ${pkgdir}/"
}

# --- Main ---
TARGET="${1:-all}"

echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Gem Build System v${VERSION}            ║${NC}"
echo -e "${BLUE}║   HintyCloud - Agentic AI            ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"

case "$TARGET" in
    python)    build_python ;;
    rust)      build_rust ;;
    go)        build_go ;;
    node)      build_node ;;
    c)         build_c ;;
    java)      build_java ;;
    all-langs) build_rust; build_go; build_node; build_c; build_java ;;
    package)   package_all ;;
    all)
        build_python
        build_rust
        build_go
        build_node
        build_c
        build_java
        package_all
        ;;
    *)
        echo "Usage: $0 {python|rust|go|node|c|java|all-langs|package|all}"
        exit 1
        ;;
esac

echo ""
ok "Build complete!"
