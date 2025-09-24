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

# Check for Node.js
if ! command_exists node; then
  missing_deps=1
  echo "❌ Node.js is not installed."
  echo ""
  echo "To install Node.js, visit the official download page:"
  echo "👉 https://nodejs.org/en/download/"
  echo ""
  echo "Or install it using a package manager:"
  echo ""
  echo "🔹 macOS (Homebrew):"
  echo "    brew install node"
  echo ""
  echo "🔹 Ubuntu/Debian:"
  echo "    sudo apt-get install -y nodejs npm"
  echo ""
  echo "🔹 Arch Linux:"
  echo "    sudo pacman -S nodejs npm"
  echo ""
fi

# Check for npm
if ! command_exists npm; then
  missing_deps=1
  echo "❌ npm is not installed."
  echo ""
  echo "npm is typically included with Node.js."
  echo "If you have Node.js but not npm, please reinstall Node.js."
  echo ""
fi

# Exit with a bad exit code if any dependencies are missing
if [ "$missing_deps" -ne 0 ]; then
  echo "Install the missing dependencies and ensure they are on your path. Then run this command again."
  exit 1
fi

# Check if package.json exists
if [ ! -f "package.json" ]; then
    echo "Error: No package.json found. Please run this script in the TypeScript project directory."
    exit 1
fi

# Check if wit directory exists
if [ ! -d "wit" ]; then
    echo "Error: No wit directory found. Please ensure the WIT interface definitions are present."
    exit 1
fi

# Check if app.ts exists
if [ ! -f "app.ts" ]; then
    echo "Error: No app.ts found. Please ensure the main component file is present."
    exit 1
fi

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    echo "Installing Node.js dependencies..."
    npm install
else
    echo "✅ Node.js dependencies already installed"
fi

# Fetch WIT dependencies using wkg
echo "Fetching WIT dependencies..."
wkg wit fetch

# Run TypeScript type checking
echo "Running TypeScript type checking..."
npm run typecheck

# Clean any previous build artifacts
echo "Cleaning previous build artifacts..."
rm -rf dist/
mkdir -p dist

# Compile TypeScript to JavaScript
echo "Compiling TypeScript to JavaScript..."
npm run compile

# Build the JavaScript component to WASM using ComponentizeJS
echo "Building JavaScript component to WASM..."

# Use ComponentizeJS to build the WASM component from the compiled JavaScript
# The npx command will use the locally installed version from package.json
npx jco componentize \
    -w wit/ \
    -o dist/plugin.wasm \
    dist/app.js

# Check if the generated .wasm file exists
if [ ! -f "dist/plugin.wasm" ]; then
    echo "Error: WASM file generation failed"
    exit 1
fi

echo "✓ Build complete. WASM component created at dist/plugin.wasm"

# Show file size
echo "File size: $(du -h dist/plugin.wasm | cut -f1)"