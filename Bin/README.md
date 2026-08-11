# GemBin — Pre-compiled Binaries & Multi-language Implementations

> **Gem** is an agentic AI ecosystem by [HintyCloud](https://github.com/HintyCloud) for development, automation, research, and task execution.  
> **GemBin** provides pre-compiled binaries and alternative language implementations so every user — regardless of platform or preference — can run Gem instantly.

---

## 🚀 Quick Start

### Linux (x86_64) — Pre-compiled Binary

```bash
# Download and install in one line
curl -sL https://raw.githubusercontent.com/HintyCloud/Gem-Cli/main/GemBin/linux-x86_64/install.sh | bash

# Or manually:
chmod +x gem
sudo mv gem /usr/local/bin/gem
gem --version
```

### Windows (x86_64)

```powershell
# Download gem.exe, then run:
gem.exe --version
```

### Termux / Android

```bash
pkg install python
pip install gem-cli
# Or use the pre-compiled binary:
chmod +x gem
./gem --version
```

---

## 📦 Pre-compiled Binaries (`GemBin/`)

| Platform | Arch | Binary | Size | Status |
|----------|------|--------|------|--------|
| Linux | x86_64 | `linux-x86_64/gem` | ~15 MB | ✅ Compiled |
| Linux | ARM64 | `linux-arm64/gem` | — | 🔄 Cross-compile |
| Windows | x86_64 | `windows-x86_64/gem.exe` | — | 🔄 Cross-compile |
| Windows | ARM64 | `windows-arm64/gem.exe` | — | 🔄 Cross-compile |
| macOS | Intel (x86_64) | `macos-x86_64/gem` | — | 🔄 Cross-compile |
| macOS | Apple Silicon (ARM64) | `macos-arm64/gem` | — | 🔄 Cross-compile |
| Termux | ARM64 | `termux-arm64/gem` | — | 🔄 Cross-compile |

> **Note:** Binaries marked 🔄 require cross-compilation in CI. See the [CI/CD](#cicd) section.

Each platform directory contains:
- **`gem`** (or `gem.exe`) — The pre-compiled binary
- **`platform.json`** — Machine-readable metadata
- **`VERSION`** — Version file
- **`CHECKSUMS.txt`** — SHA256 checksums for integrity verification
- **`install.sh`** / **`install.bat`** — Platform-specific installer
- **`uninstall.sh`** — Platform-specific uninstaller

---

## 🌍 Multi-language Implementations (`GemBin/etc/`)

Gem is not just Python anymore! Choose the implementation that fits your stack:

| Language | Directory | Build | Binary Size | Status |
|----------|-----------|-------|-------------|--------|
| 🦀 **Rust** | `etc/gem-rust/` | `cargo build --release` | ~5 MB | ✅ Compiles |
| 🐹 **Go** | `etc/gem-go/` | `go build -o gem .` | ~8 MB | ✅ Compiles |
| 🟢 **Node.js** | `etc/gem-node/` | `npm run build` | ~20 MB* | ✅ Compiles |
| 🔵 **C** | `etc/gem-c/` | `make linux` | ~70 KB | ✅ Compiles |
| 🐚 **Bash** | `etc/gem-bash/` | No build needed | ~30 KB | ✅ Ready |
| ☕ **Java** | `etc/gem-java/` | `mvn package` | ~15 MB* | ✅ Compiles |

*\*With runtime/dependencies included*

### Why multiple languages?

1. **Performance** — Rust, Go, and C binaries start in milliseconds vs. Python's seconds
2. **No Python dependency** — Users without Python can still use Gem
3. **Smaller binaries** — C and Rust produce tiny statically-linked binaries
4. **Enterprise integration** — Java version integrates with JVM ecosystems
5. **DevOps simplicity** — Go single-binary is perfect for containers and CI
6. **Lightweight** — Bash version works on any Unix with zero dependencies
7. **Full-stack teams** — Node.js/TypeScript version for JavaScript-native teams

---

## 🦀 Rust Implementation (`etc/gem-rust/`)

```bash
cd etc/gem-rust
cargo build --release
./target/release/gem --help
```

**Features:** Full CLI with clap, async runtime (tokio), OpenCode provider via reqwest, TOML config, rustyline chat REPL, 7 tools, agent loop, memory system.

**Cross-compile:**
```bash
# Linux ARM64
rustup target add aarch64-unknown-linux-gnu
cargo build --release --target aarch64-unknown-linux-gnu

# macOS
rustup target add x86_64-apple-darwin
cargo build --release --target x86_64-apple-darwin

# Windows
rustup target add x86_64-pc-windows-msvc
cargo build --release --target x86_64-pc-windows-msvc
```

---

## 🐹 Go Implementation (`etc/gem-go/`)

```bash
cd etc/gem-go
go mod tidy
go build -o gem .
./gem --help
```

**Features:** Cobra CLI, OpenCode provider, tool registry, agent loop, job manager, memory store, platform detection.

**Cross-compile:**
```bash
GOOS=linux   GOARCH=amd64   go build -o gem-linux-amd64 .
GOOS=linux   GOARCH=arm64   go build -o gem-linux-arm64 .
GOOS=darwin  GOARCH=amd64   go build -o gem-macos-amd64 .
GOOS=darwin  GOARCH=arm64   go build -o gem-macos-arm64 .
GOOS=windows GOARCH=amd64   go build -o gem-windows-amd64.exe .
```

---

## 🟢 Node.js/TypeScript Implementation (`etc/gem-node/`)

```bash
cd etc/gem-node
npm install
npm run build
node dist/index.js --help

# Or run directly with tsx:
npx tsx src/index.ts --help
```

**Features:** Commander CLI, Express server, OpenAI SDK integration, TOML config, 7 tools, agent loop with streaming, swarm orchestration, interactive chat with inquirer.

---

## 🔵 C Implementation (`etc/gem-c/`)

```bash
cd etc/gem-c
make linux        # Linux x86_64
make macos        # macOS (cross-compile)
make windows      # Windows (cross-compile)
make release      # Optimized build
./build/gem --help
```

**Features:** Minimal dependencies (libcurl, pthreads), vendored cJSON, readline support, 9 commands, OpenCode provider, 7 tools, agent loop, JSON-persistent memory. Ultra-lightweight at ~70KB.

---

## 🐚 Bash Implementation (`etc/gem-bash/`)

```bash
cd etc/gem-bash
chmod +x gem
./gem --help

# Install globally:
./install.sh
```

**Features:** Zero dependencies (uses curl for API calls), POSIX-compliant where possible, 9+ subcommands, 16 slash commands, 4 providers, 7 tools, agent loop, persistent memory, platform detection. Perfect for servers, CI, and minimal environments.

---

## ☕ Java Implementation (`etc/gem-java/`)

```bash
cd etc/gem-java
mvn clean package
java -jar target/gem-cli-1.0.0.jar --help
```

**Features:** Picocli CLI, OkHttp provider, Jackson JSON, JLine REPL, SLF4J logging, Maven shade plugin for fat JAR, job queue with thread pool.

---

## 🔐 Security

All binaries include:
- **SHA256 checksums** in `CHECKSUMS.txt` for integrity verification
- **Path boundary validation** — all file operations stay within workspace
- **Command blocking** — destructive shell commands are denied
- **Secret redaction** — API keys are redacted from logs and output
- **No hardcoded secrets** — credentials come from env vars or secrets.toml only

Verify a binary:
```bash
sha256sum -c CHECKSUMS.txt
```

---

## 🔄 CI/CD

For automated cross-compilation, use GitHub Actions:

```yaml
# .github/workflows/build-binaries.yml
name: Build Gem Binaries
on: [push, pull_request]
jobs:
  build:
    strategy:
      matrix:
        include:
          - os: ubuntu-latest
            target: linux-x86_64
          - os: ubuntu-latest
            target: linux-arm64
          - os: macos-latest
            target: macos-arm64
          - os: windows-latest
            target: windows-x86_64
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - name: Build Python binary
        run: pyinstaller --onefile gem_main.py
      - name: Build Rust binary
        run: cd etc/gem-rust && cargo build --release
      - name: Build Go binary
        run: cd etc/gem-go && go build -o gem .
      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: gem-${{ matrix.target }}
          path: gem
```

---

## 📋 Commands Reference

All implementations support the same core CLI:

| Command | Description |
|---------|-------------|
| `gem status` | Show system status (version, platform, provider, config) |
| `gem serve` | Start the Gem API server (FastAPI/Express) |
| `gem chat` | Interactive chat with slash commands |
| `gem project list` | List projects |
| `gem project create NAME` | Create a new project |
| `gem jobs` | List background jobs |
| `gem models` | Show configured model |
| `gem providers` | List available providers |
| `gem tools` | List available tools |
| `gem agents` | List agent profiles |

### Chat Slash Commands

| Command | Description |
|---------|-------------|
| `/help` | Show available commands |
| `/model` | Show current model |
| `/provider` | Show current provider |
| `/chats` | List chat sessions |
| `/new` | Start a new chat |
| `/clear` | Clear current chat |
| `/status` | Show system status |
| `/jobs` | List background jobs |
| `/agents` | List agent profiles |
| `/tools` | List tools |
| `/exit` | Exit chat |

---

## 🏗 Architecture

```
GemBin/
├── linux-x86_64/           # Pre-compiled Linux x86_64 binary
│   ├── gem                 # Executable binary
│   ├── platform.json       # Metadata
│   ├── VERSION             # Version
│   ├── CHECKSUMS.txt       # SHA256 checksums
│   ├── install.sh          # Installer
│   └── uninstall.sh        # Uninstaller
├── linux-arm64/            # Pre-compiled Linux ARM64
├── windows-x86_64/         # Pre-compiled Windows x86_64
├── windows-arm64/          # Pre-compiled Windows ARM64
├── macos-x86_64/           # Pre-compiled macOS Intel
├── macos-arm64/            # Pre-compiled macOS Apple Silicon
├── termux-arm64/           # Pre-compiled Termux/Android
├── etc/                    # Multi-language implementations
│   ├── gem-rust/           # Rust implementation
│   ├── gem-go/             # Go implementation
│   ├── gem-node/           # Node.js/TypeScript implementation
│   ├── gem-c/              # C implementation
│   ├── gem-bash/           # Bash/Shell implementation
│   └── gem-java/           # Java implementation
└── README.md               # This file
```

---

## 📜 License

All Gem implementations are licensed under **GPL-3.0** — see the [LICENSE](https://github.com/HintyCloud/Gem-Cli/blob/main/LICENSE) file.

---

## 🤝 Contributing

Contributions are welcome for any language implementation! See [CONTRIBUTING.md](https://github.com/HintyCloud/Gem-Cli/blob/main/CONTRIBUTING.md).

---

*Built with ❤️ by [HintyCloud](https://github.com/HintyCloud)*
