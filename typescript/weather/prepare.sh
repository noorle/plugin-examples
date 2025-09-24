#!/bin/bash

# prepare.sh - Set up development environment for TypeScript WebAssembly template
# This script installs all required dependencies for building WASM components

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CHECK_ONLY=0
CI_MODE=0
FORCE_INSTALL=0
VERBOSE=0
INSTALLED_TOOLS=()
LOCKFILE="/tmp/prepare-wasm-ts-$(whoami).lock"

# Minimum version requirements
MIN_NODE_VERSION="18.0.0"
MIN_DISK_SPACE_MB=500

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --check)
            CHECK_ONLY=1
            shift
            ;;
        --ci)
            CI_MODE=1
            shift
            ;;
        --force)
            FORCE_INSTALL=1
            shift
            ;;
        --verbose)
            VERBOSE=1
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --check    Only check if dependencies are installed"
            echo "  --ci       Run in CI mode (non-interactive)"
            echo "  --force    Force reinstall of all dependencies"
            echo "  --verbose  Show detailed output"
            echo "  --help     Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run '$0 --help' for usage information"
            exit 2
            ;;
    esac
done

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_verbose() {
    if [ "$VERBOSE" -eq 1 ]; then
        echo -e "${BLUE}→${NC} $1"
    fi
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

track_installation() {
    INSTALLED_TOOLS+=("$1")
    log_verbose "Tracked installation: $1"
}

detect_os() {
    # Check for WSL first
    if grep -q Microsoft /proc/version 2>/dev/null; then
        echo "wsl"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/debian_version ]; then
            echo "debian"
        elif [ -f /etc/redhat-release ]; then
            echo "redhat"
        elif [ -f /etc/arch-release ]; then
            echo "arch"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

detect_package_manager() {
    if command_exists brew; then
        echo "brew"
    elif command_exists apt-get; then
        echo "apt"
    elif command_exists yum; then
        echo "yum"
    elif command_exists pacman; then
        echo "pacman"
    elif command_exists apk; then
        echo "apk"
    else
        echo "none"
    fi
}

acquire_lock() {
    if [ -f "$LOCKFILE" ]; then
        local pid=$(cat "$LOCKFILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            log_error "Another instance is already running (PID: $pid)"
            exit 1
        else
            log_verbose "Removing stale lockfile"
            rm -f "$LOCKFILE"
        fi
    fi

    echo $$ > "$LOCKFILE"
    trap 'rm -f "$LOCKFILE"' EXIT
}

check_network() {
    log_verbose "Checking network connectivity..."

    if ! curl -s --head --connect-timeout 5 https://github.com > /dev/null 2>&1; then
        log_error "No network connectivity detected"
        log_info "This script requires internet access to download dependencies"
        return 1
    fi

    log_verbose "Network connectivity OK"
    return 0
}

check_disk_space() {
    log_verbose "Checking available disk space..."

    local available_mb
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS df might need different parsing
        available_mb=$(df -k "$HOME" 2>/dev/null | awk 'NR==2 {print int($4/1024)}')
    else
        available_mb=$(df -k "$HOME" 2>/dev/null | awk 'NR==2 {print int($4/1024)}')
    fi

    # Add null check
    if [ -z "$available_mb" ]; then
        log_warning "Could not determine available disk space"
        return 0  # Continue anyway
    fi

    if [ "$available_mb" -lt "$MIN_DISK_SPACE_MB" ]; then
        log_warning "Low disk space: ${available_mb}MB available, ${MIN_DISK_SPACE_MB}MB recommended"

        if [ "$CI_MODE" -eq 0 ] && [ "$CHECK_ONLY" -eq 0 ]; then
            read -p "Continue anyway? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                return 1
            fi
        fi
    else
        log_verbose "Disk space OK: ${available_mb}MB available"
    fi

    return 0
}

check_system_deps() {
    local missing=()

    log_verbose "Checking system dependencies..."

    # Check for build essentials
    if ! command_exists gcc && ! command_exists clang; then
        missing+=("C compiler (gcc/clang)")
    fi

    if ! command_exists make; then
        missing+=("make")
    fi

    if ! command_exists curl && ! command_exists wget; then
        missing+=("curl or wget")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing system dependencies: ${missing[*]}"
        log_info "Install build essentials for your system:"

        local pkg_mgr=$(detect_package_manager)
        case $pkg_mgr in
            apt)
                echo "  sudo apt-get install build-essential curl"
                ;;
            yum)
                echo "  sudo yum groupinstall 'Development Tools' && sudo yum install curl"
                ;;
            brew)
                echo "  xcode-select --install"
                ;;
            pacman)
                echo "  sudo pacman -S base-devel curl"
                ;;
        esac
        return 1
    fi

    log_verbose "System dependencies OK"
    return 0
}

check_node_version() {
    if command_exists node; then
        local version=$(node --version 2>/dev/null | sed 's/^v//' || echo "0.0.0")
        local major=$(echo "$version" | cut -d. -f1)
        local minor=$(echo "$version" | cut -d. -f2)
        local req_major=$(echo "$MIN_NODE_VERSION" | cut -d. -f1)
        local req_minor=$(echo "$MIN_NODE_VERSION" | cut -d. -f2)

        if [ "$major" -lt "$req_major" ] || ([ "$major" -eq "$req_major" ] && [ "$minor" -lt "$req_minor" ]); then
            log_error "Node.js $MIN_NODE_VERSION+ is required (found $version)"
            return 1
        fi

        log_verbose "Node.js version $version OK"
    else
        return 1
    fi
    return 0
}

update_shell_profile() {
    local shell_profile=""

    # Detect shell profile file
    if [ -n "$BASH_VERSION" ]; then
        shell_profile="$HOME/.bashrc"
        # On macOS, .bash_profile might be used instead
        [ -f "$HOME/.bash_profile" ] && shell_profile="$HOME/.bash_profile"
    elif [ -n "$ZSH_VERSION" ]; then
        shell_profile="$HOME/.zshrc"
    elif [ -n "$FISH_VERSION" ]; then
        shell_profile="$HOME/.config/fish/config.fish"
    elif [ -f "$HOME/.profile" ]; then
        shell_profile="$HOME/.profile"
    fi

    # Create shell profile if it doesn't exist
    if [ -n "$shell_profile" ] && [ ! -f "$shell_profile" ]; then
        touch "$shell_profile"
        log_info "Created $shell_profile"
    fi

    if [ -n "$shell_profile" ] && [ -f "$shell_profile" ]; then
        local paths_added=0
        local changes_made=0

        # Check and add cargo path
        if ! grep -q "/.cargo/bin" "$shell_profile"; then
            if [ $paths_added -eq 0 ]; then
                echo '' >> "$shell_profile"
                echo '# Added by Noorle prepare.sh' >> "$shell_profile"
                paths_added=1
            fi
            echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$shell_profile"
            changes_made=1
            log_success "Added Cargo to PATH in $shell_profile"
        fi

        # Handle Fish shell differently
        if [[ "$shell_profile" == *"fish/config.fish" ]]; then
            # Fish uses different syntax
            sed -i.bak 's/export PATH=/set -gx PATH /g' "$shell_profile"
            rm "${shell_profile}.bak"
        fi

        if [ $changes_made -eq 1 ]; then
            log_success "Shell profile updated. Changes will take effect in new shell sessions."
            log_info "To apply changes to current session, run: source $shell_profile"

            # Also export PATH for current script execution
            export PATH="$HOME/.cargo/bin:$PATH"
            return 0
        else
            log_verbose "PATH already configured in $shell_profile"
            return 0
        fi
    fi

    log_warning "Could not detect shell profile to update PATH"
    return 1
}

# Installation functions
install_rust() {
    log_info "Installing Rust and Cargo..."

    if [ "$CI_MODE" -eq 1 ]; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile minimal || {
            log_error "Failed to install Rust"
            return 1
        }
    else
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh || {
            log_error "Failed to install Rust"
            return 1
        }
    fi

    # Source cargo env for current session
    if [ -f "$HOME/.cargo/env" ]; then
        source "$HOME/.cargo/env"
    fi

    export PATH="$HOME/.cargo/bin:$PATH"
    track_installation "rust"
}

install_node() {
    local pkg_mgr="$1"

    log_info "Installing Node.js..."

    case $pkg_mgr in
        brew)
            brew install node
            ;;
        apt)
            # Use NodeSource repository for latest Node.js
            curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
            sudo apt-get install -y nodejs
            ;;
        yum)
            curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
            sudo yum install -y nodejs
            ;;
        pacman)
            sudo pacman -S --noconfirm nodejs npm
            ;;
        apk)
            sudo apk add --no-cache nodejs npm
            ;;
        wsl)
            # WSL might need special handling
            curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
            sudo apt-get install -y nodejs
            ;;
        *)
            log_error "Cannot auto-install Node.js. Please install manually:"
            echo "  Visit: https://nodejs.org/en/download/"
            return 1
            ;;
    esac

    track_installation "node"
}

install_npm_packages() {
    log_info "Installing npm packages from package.json..."

    # npm packages (typescript, jco, componentize-js) are installed via npm install
    if command_exists npm; then
        if [ -f "package.json" ]; then
            # Install all npm dependencies
            log_info "Running 'npm install' to install TypeScript and JavaScript packages..."
            npm install || {
                log_error "Failed to install npm dependencies"
                return 1
            }

            # Verify TypeScript was installed
            if [ -f "node_modules/.bin/tsc" ]; then
                log_success "TypeScript installed successfully"
                track_installation "typescript"
            else
                log_warning "TypeScript compiler not found in node_modules"
            fi

            # Verify jco was installed
            if [ -f "node_modules/.bin/jco" ]; then
                log_success "jco and componentize-js installed successfully"
                track_installation "jco"
                track_installation "componentize-js"
                return 0
            else
                log_error "jco was not installed by npm install"
                log_info "Check that @bytecodealliance/jco is in package.json dependencies"
                return 1
            fi
        else
            log_error "No package.json found in current directory"
            return 1
        fi
    else
        log_error "npm is required to install TypeScript packages"
        return 1
    fi
}

install_cargo_tool() {
    local tool="$1"
    local package="${2:-$tool}"

    log_info "Installing $tool..."

    local install_cmd="cargo install"
    if [ "$package" == "wasm-tools" ]; then
        install_cmd="$install_cmd --locked"
    fi

    $install_cmd "$package" || {
        log_error "Failed to install $package via cargo"

        # Provide helpful error messages
        if [[ "$?" -eq 101 ]]; then
            log_info "Try updating Rust: rustup update"
        fi
        return 1
    }

    track_installation "$tool"
}

# Main dependency checking and installation
check_and_install() {
    local tool="$1"
    local install_func="$2"
    local install_args="${3:-}"

    if [ "$FORCE_INSTALL" -eq 1 ] || ! command_exists "$tool"; then
        if [ "$CHECK_ONLY" -eq 1 ]; then
            log_error "$tool is not installed"
            return 1
        else
            log_verbose "Installing $tool using $install_func"
            $install_func $install_args || return 1

            # Verify installation
            if command_exists "$tool"; then
                log_success "$tool installed successfully"
            else
                log_error "Failed to install $tool"
                return 1
            fi
        fi
    else
        log_success "$tool is already installed"

        # Check version if verbose
        if [ "$VERBOSE" -eq 1 ] && command_exists "$tool"; then
            local version_cmd=""
            case "$tool" in
                node) version_cmd="node --version" ;;
                npm) version_cmd="npm --version" ;;
                cargo) version_cmd="cargo --version" ;;
                wkg) version_cmd="wkg --version" ;;
                wasmtime) version_cmd="wasmtime --version" ;;
                wasm-tools) version_cmd="wasm-tools --version" ;;
            esac

            if [ -n "$version_cmd" ]; then
                log_verbose "  Version: $($version_cmd 2>&1 | head -n1)"
            fi
        fi
    fi

    return 0
}

# Cleanup function for rollback
cleanup_on_error() {
    if [ ${#INSTALLED_TOOLS[@]} -gt 0 ]; then
        log_warning "Installation failed. Installed tools: ${INSTALLED_TOOLS[*]}"
        log_info "To rollback, you may want to remove these tools manually"
    fi

    # Remove lockfile on error
    rm -f "$LOCKFILE"
}

# Trap errors for cleanup
trap cleanup_on_error ERR

# Main execution
main() {
    echo "======================================="
    echo "TypeScript WebAssembly Template Setup"
    echo "======================================="
    echo ""

    # Acquire lock to prevent concurrent runs
    if [ "$CHECK_ONLY" -eq 0 ]; then
        acquire_lock
    fi

    local os_type=$(detect_os)
    local pkg_mgr=$(detect_package_manager)
    local missing_deps=0

    log_info "Detected OS: $os_type"
    log_info "Package manager: $pkg_mgr"
    echo ""

    # Pre-flight checks
    log_info "Running pre-flight checks..."

    # Check network connectivity (skip in check-only mode)
    if [ "$CHECK_ONLY" -eq 0 ]; then
        if ! check_network; then
            log_error "Network connectivity required for installation"
            exit 1
        fi
    fi

    # Check disk space
    if ! check_disk_space; then
        log_error "Insufficient disk space"
        exit 1
    fi

    # Check system dependencies
    if ! check_system_deps; then
        if [ "$CHECK_ONLY" -eq 1 ]; then
            missing_deps=1
        else
            log_error "Please install system dependencies first"
            exit 1
        fi
    fi

    echo ""

    # Section 1: Language-specific dependencies
    echo "Checking language-specific dependencies..."
    echo "----------------------------------------"

    # Node.js
    if ! check_and_install "node" "install_node" "$pkg_mgr"; then
        missing_deps=1
    elif ! check_node_version; then
        missing_deps=1
        if [ "$CHECK_ONLY" -eq 0 ]; then
            log_error "Please upgrade Node.js to $MIN_NODE_VERSION+"
            exit 1
        fi
    fi

    # npm
    if ! check_and_install "npm" "install_node" "$pkg_mgr"; then
        missing_deps=1
    fi

    # Install npm packages (typescript, jco, componentize-js)
    if [ "$CHECK_ONLY" -eq 0 ]; then
        if ! [ -f "node_modules/.bin/jco" ] || ! [ -f "node_modules/.bin/tsc" ]; then
            install_npm_packages || {
                missing_deps=1
                log_error "Failed to install npm packages"
            }
        else
            log_success "TypeScript and jco are already installed in node_modules"
        fi
    else
        # In check mode, just verify if packages are installed
        if [ -f "node_modules/.bin/tsc" ]; then
            log_success "TypeScript is installed in node_modules"
        else
            log_warning "TypeScript not installed (run 'npm install' to install)"
            missing_deps=1
        fi

        if [ -f "node_modules/.bin/jco" ]; then
            log_success "jco is installed in node_modules"
        else
            log_warning "jco not installed (run 'npm install' to install)"
            missing_deps=1
        fi
    fi

    echo ""

    # Section 2: WebAssembly toolchain
    echo "Checking WebAssembly toolchain..."
    echo "---------------------------------"

    # Rust/Cargo (needed for WASM tools)
    if ! check_and_install "cargo" "install_rust"; then
        missing_deps=1
    fi

    # Ensure cargo bin is in PATH
    export PATH="$HOME/.cargo/bin:$PATH"

    # wkg (WIT package manager)
    if ! check_and_install "wkg" "install_cargo_tool" "wkg"; then
        missing_deps=1
    fi

    # wasmtime (WASM runtime)
    if ! check_and_install "wasmtime" "install_cargo_tool" "wasmtime-cli"; then
        missing_deps=1
    fi

    # wasm-tools (WASM component tools)
    if ! check_and_install "wasm-tools" "install_cargo_tool" "wasm-tools"; then
        missing_deps=1
    fi

    echo ""

    # Summary
    echo "======================================="
    if [ "$CHECK_ONLY" -eq 1 ]; then
        if [ "$missing_deps" -eq 0 ]; then
            log_success "All dependencies are installed!"
            echo ""
            echo "Versions:"
            echo "  Node.js:       $(node --version 2>&1 | sed 's/^v//')"
            echo "  npm:           $(npm --version 2>&1)"
            # TypeScript and jco are installed per-project
            if [ -f "node_modules/.bin/tsc" ]; then
                echo "  TypeScript:    $(npx tsc --version 2>&1 | sed 's/Version //')"
            else
                echo "  TypeScript:    not installed"
            fi
            if [ -f "node_modules/.bin/jco" ]; then
                echo "  jco:           $(npx jco --version 2>&1 | sed 's/^jco //')"
            else
                echo "  jco:           not installed"
            fi
            echo "  Cargo:         $(cargo --version 2>&1 | cut -d' ' -f2)"
            echo "  wkg:           $(wkg --version 2>&1 | sed 's/^wkg //')"
            echo "  wasmtime:      $(wasmtime --version 2>&1 | sed 's/^wasmtime //' | cut -d' ' -f1)"
            echo "  wasm-tools:    $(wasm-tools --version 2>&1 | cut -d' ' -f2)"
        else
            log_error "Some dependencies are missing"
            echo ""
            echo "Run without --check to install missing dependencies"
            exit 1
        fi
    else
        if [ "$missing_deps" -eq 0 ]; then
            log_success "Environment setup complete!"

            # Automatically update shell profile
            update_shell_profile

            echo ""
            echo "Build your component:"
            echo "     ./build.sh        # Build in release mode"
            echo "     ./build.sh debug  # Build in debug mode"
        else
            log_error "Setup incomplete - some dependencies failed to install"
            echo ""
            echo "Please check the errors above and try:"
            echo "  1. Installing failed dependencies manually"
            echo "  2. Running this script again with --verbose for more details"
            echo "  3. Checking system requirements"
            exit 1
        fi
    fi
}

# Run main function
main