#!/bin/bash

# Exit on any error
set -e

# Function to check if a command exists
command_exists () {
  command -v "$1" >/dev/null 2>&1
}

# Check dependencies
missing_deps=0

# Check for Go
if ! command_exists go; then
  missing_deps=1
  echo "❌ Go is not installed."
  echo ""
  echo "To install Go, visit the official download page:"
  echo "👉 https://go.dev/dl/"
  echo ""
  echo "Or install it using a package manager:"
  echo ""
  echo "🔹 macOS (Homebrew):"
  echo "    brew install go"
  echo ""
  echo "🔹 Ubuntu/Debian:"
  echo "    sudo apt-get install -y golang"
  echo ""
  echo "🔹 Arch Linux:"
  echo "    sudo pacman -S go"
  echo ""
fi

# Check for TinyGo
if ! command_exists tinygo; then
  missing_deps=1
  echo "❌ TinyGo is not installed."
  echo ""
  echo "TinyGo is required for building WASI components."
  echo ""
  echo "To install TinyGo:"
  echo "👉 https://tinygo.org/getting-started/install/"
  echo ""
  echo "🔹 macOS (Homebrew):"
  echo "    brew install tinygo"
  echo ""
  echo "🔹 Linux:"
  echo "    wget https://github.com/tinygo-org/tinygo/releases/download/v0.33.0/tinygo_0.33.0_amd64.deb"
  echo "    sudo dpkg -i tinygo_0.33.0_amd64.deb"
  echo ""
fi

# Check for wkg (WIT package manager)
if ! command_exists wkg; then
  missing_deps=1
  echo "❌ wkg is not installed."
  echo ""
  echo "wkg is the WebAssembly Interface Types package manager."
  echo ""
  echo "To install wkg:"
  echo "👉 cargo install wkg"
  echo ""
fi

# Check for wit-bindgen-go
if ! command_exists wit-bindgen-go; then
  missing_deps=1
  echo "❌ wit-bindgen-go is not installed."
  echo ""
  echo "wit-bindgen-go generates Go bindings from WIT files."
  echo ""
  echo "To install wit-bindgen-go:"
  echo "👉 go install go.bytecodealliance.org/cmd/wit-bindgen-go@latest"
  echo ""
fi

# Check for wasm-tools
if ! command_exists wasm-tools; then
  missing_deps=1
  echo "❌ wasm-tools is not installed."
  echo ""
  echo "wasm-tools is required for WebAssembly component manipulation."
  echo ""
  echo "To install wasm-tools:"
  echo "👉 cargo install wasm-tools"
  echo ""
  echo "Or download from:"
  echo "👉 https://github.com/bytecodealliance/wasm-tools/releases"
  echo ""
fi

# Exit with a bad exit code if any dependencies are missing
if [ "$missing_deps" -ne 0 ]; then
  echo "Install the missing dependencies and ensure they are on your path. Then run this command again."
  exit 1
fi

# Check if go.mod exists
if [ ! -f "go.mod" ]; then
    echo "Error: No go.mod found. Please run this script in the Go project directory."
    exit 1
fi

# Check if wit directory exists
if [ ! -d "wit" ]; then
    echo "Error: No wit directory found. Please ensure the WIT interface definitions are present."
    exit 1
fi

# Check if main.go exists
if [ ! -f "main.go" ]; then
    echo "Error: No main.go found. Please ensure the main component file is present."
    exit 1
fi

# Clean build directories
echo "Cleaning build directories..."
rm -rf gen
mkdir -p dist

# Bundle WIT dependencies
echo "Bundling WIT dependencies..."
wkg wit build -o dist/wit-package.wasm

# Extract world name from the WIT package
echo "Extracting world name..."
WORLD_NAME=$(wasm-tools component wit dist/wit-package.wasm | grep "^world" | head -1 | awk '{print $2}')
if [ -z "$WORLD_NAME" ]; then
    echo "Error: Could not extract world name from WIT package"
    exit 1
fi
echo "Found world: $WORLD_NAME"

# Generate WIT bindings
echo "Generating WIT bindings..."
wit-bindgen-go generate --world "$WORLD_NAME" --out gen ./dist/wit-package.wasm

# Tidy go.mod
echo "Tidying go.mod..."
go mod tidy

# Default mode is release for smaller, production-ready builds
MODE=${1:-release}

# Validate mode
if [[ "$MODE" != "debug" && "$MODE" != "release" ]]; then
    echo "Error: Invalid mode. Use 'debug' or 'release'."
    exit 1
fi

# Set build flags based on mode
if [ "$MODE" = "release" ]; then
    BUILD_FLAGS="-opt=2 -no-debug"
    echo "Building Go project to WASM in release mode..."
else
    BUILD_FLAGS=""
    echo "Building Go project to WASM in debug mode..."
fi

# Build with TinyGo for WASI Preview 2
echo "Building with TinyGo..."
tinygo build -target=wasip2 --wit-package ./dist/wit-package.wasm --wit-world "$WORLD_NAME" -scheduler=none $BUILD_FLAGS -o plugin.wasm .

# Check if the build succeeded
if [ ! -f "plugin.wasm" ]; then
    echo "Error: Build failed. No plugin.wasm file generated."
    exit 1
fi

# Create dist directory if it doesn't exist
mkdir -p dist

# Move to standardized location
mv plugin.wasm dist/plugin.wasm

echo "✓ Build complete. WASM component created at dist/plugin.wasm"

# Show file size
echo "File size: $(du -h dist/plugin.wasm | cut -f1)"