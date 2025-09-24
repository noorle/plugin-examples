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

# Check for Python
if ! command_exists python3; then
  missing_deps=1
  echo "❌ Python 3 is not installed."
  echo ""
  echo "To install Python, visit the official download page:"
  echo "👉 https://www.python.org/downloads/"
  echo ""
  echo "Or install it using a package manager:"
  echo ""
  echo "🔹 macOS (Homebrew):"
  echo "    brew install python3"
  echo ""
  echo "🔹 Ubuntu/Debian:"
  echo "    sudo apt-get install -y python3 python3-pip"
  echo ""
  echo "🔹 Arch Linux:"
  echo "    sudo pacman -S python"
  echo ""
fi

# Check for uv
if ! command_exists uv; then
  missing_deps=1
  echo "❌ uv is not installed."
  echo ""
  echo "To install uv:"
  echo "👉 curl -LsSf https://astral.sh/uv/install.sh | sh"
  echo "Or with Homebrew:"
  echo "👉 brew install uv"
  echo ""
fi

# Exit with a bad exit code if any dependencies are missing
if [ "$missing_deps" -ne 0 ]; then
  echo "Install the missing dependencies and ensure they are on your path. Then run this command again."
  exit 1
fi

# Check if pyproject.toml exists
if [ ! -f "pyproject.toml" ]; then
    echo "Error: No pyproject.toml found. Please run this script in the Python project directory."
    exit 1
fi

# Check if wit directory exists
if [ ! -d "wit" ]; then
    echo "Error: No wit directory found. Please ensure the WIT interface definitions are present."
    exit 1
fi

# Create virtual environment if it doesn't exist
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment with uv..."
    uv venv
fi

# Install Python dependencies using uv sync
echo "Installing Python dependencies..."
uv sync

# Fetch WIT dependencies using wkg
echo "Fetching WIT dependencies..."
wkg wit fetch

# Extract world name from WIT file
echo "Extracting world name from WIT files..."
WORLD_NAME=$(grep -h "^world " wit/*.wit 2>/dev/null | head -1 | sed 's/^world \([a-zA-Z0-9_-]*\).*/\1/')
if [ -z "$WORLD_NAME" ]; then
    echo "Error: Could not extract world name from WIT files"
    exit 1
fi
echo "Found world: $WORLD_NAME"

# Clean up old bindings if they exist
if [ -d "wit_world" ]; then
    echo "Cleaning old Python bindings..."
    rm -rf wit_world
fi

# Generate Python bindings from WIT
echo "Generating Python bindings..."
uv run componentize-py -d wit/ -w "$WORLD_NAME" bindings .

# Build the Python component to WASM
echo "Building Python component to WASM..."

# Create dist directory if it doesn't exist
mkdir -p dist

# Build the component
# Note: Replace 'app' with your main module name if different
if [ "$MODE" = "release" ]; then
    echo "Building in release mode..."
    uv run componentize-py \
        -d wit/ \
        -w "$WORLD_NAME" \
        componentize \
        app \
        -o dist/plugin.wasm
else
    echo "Building in debug mode..."
    uv run componentize-py \
        -d wit/ \
        -w "$WORLD_NAME" \
        componentize \
        app \
        -o dist/plugin.wasm
fi

# Check if the generated .wasm file exists
if [ ! -f "dist/plugin.wasm" ]; then
    echo "Error: WASM file generation failed"
    exit 1
fi

echo "✓ Build complete. WASM file created at dist/plugin.wasm"