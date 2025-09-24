#!/bin/bash

# Exit on any error
set -e

# Function to check if a command exists
command_exists () {
  command -v "$1" >/dev/null 2>&1
}

# Default mode is release for smaller, production-ready builds
MODE=${1:-release}

# Validate mode
if [[ "$MODE" != "debug" && "$MODE" != "release" ]]; then
    echo "Error: Invalid mode. Use 'debug' or 'release'."
    exit 1
fi

# Check dependencies
missing_deps=0

# Check for Cargo
if ! command_exists cargo; then
  missing_deps=1
  echo "❌ Cargo/rust is not installed."
  echo ""
  echo "To install Rust, visit the official download page:"
  echo "👉 https://www.rust-lang.org/tools/install"
  echo ""
  echo "Or install it using a package manager:"
  echo ""
  echo "🔹 macOS (Homebrew):"
  echo "    brew install cargo"
  echo ""
  echo "🔹 Ubuntu/Debian:"
  echo "    sudo apt-get install -y cargo"
  echo ""
  echo "🔹 Arch Linux:"
  echo "    sudo pacman -S rust"
  echo ""
fi

if ! command_exists rustup; then
  missing_deps=1
  echo "❌ rustup is missing. Check your rust installation."
  echo ""
fi

# Exit with a bad exit code if any dependencies are missing
if [ "$missing_deps" -ne 0 ]; then
  echo "Install the missing dependencies and ensure they are on your path. Then run this command again."
  exit 1
fi

# Check if Cargo.toml exists
if [ ! -f "Cargo.toml" ]; then
    echo "Error: No Cargo.toml found. Please run this script in a Rust project directory."
    exit 1
fi

# Add WASM target if not already installed
if ! (rustup target list --installed | grep -q '^wasm32-wasip2$'); then
  echo "Adding wasm32-wasip2 target..."
  if ! (rustup target add wasm32-wasip2); then
    echo "❌ error encountered while adding target \"wasm32-wasip2\""
    echo ""
    echo "Update rustup with:"
    echo "👉 rustup update"
    echo ""
    exit 1
  fi
else
  echo "✅ wasm32-wasip2 target already installed"
fi

# Build the project
echo "Building Rust project to WASM in $MODE mode..."
if [ "$MODE" = "release" ]; then
    cargo build --target wasm32-wasip2 --release
    WASM_DIR="target/wasm32-wasip2/release"
else
    cargo build --target wasm32-wasip2
    WASM_DIR="target/wasm32-wasip2/debug"
fi

# Find the generated .wasm file
WASM_FILE=$(find "$WASM_DIR" -maxdepth 1 -name "*.wasm" -type f | head -n 1)

# Check if the generated .wasm file exists
if [ -z "$WASM_FILE" ] || [ ! -f "$WASM_FILE" ]; then
    echo "Error: No WASM file found in $WASM_DIR"
    exit 1
fi

# Create dist directory if it doesn't exist
mkdir -p dist

# Copy to standardized location
cp "$WASM_FILE" dist/plugin.wasm

echo "✓ Build complete. WASM file copied to dist/plugin.wasm"