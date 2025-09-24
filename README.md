# Noorle Plugin Examples

A comprehensive collection of production-ready WebAssembly plugin examples demonstrating real-world patterns for building Noorle
platform plugins using the WebAssembly Component Model and WASI 0.2.

## 🎯 What This Repository Offers

This repository provides working examples of Noorle plugins that showcase:
- **HTTP API Integration** - Real-world examples using OpenWeatherMap, arXiv, and Exchange Rate APIs
- **Multi-Language Support** - Implementations in Rust, Go, Python, JavaScript, and TypeScript
- **WASI 0.2 Patterns** - Modern WebAssembly System Interface usage for secure, sandboxed execution
- **Component Model** - Type-safe, language-agnostic plugin interfaces using WIT
- **Production Patterns** - Error handling, environment configuration, and testing strategies

## 🛠️ Technologies Demonstrated

- **WebAssembly Component Model** - Next-generation WASM module composition
- **WASI Preview 2** - Secure system interface for network, filesystem, and environment access
- **WIT (WebAssembly Interface Types)** - Language-agnostic interface definitions
- **Cross-Language Compilation** - TinyGo, ComponentizeJS, componentize-py, and cargo-component

## 📚 Perfect For

- Developers building plugins for the Noorle platform
- Learning WebAssembly Component Model best practices
- Understanding WASI 0.2 HTTP client patterns
- Exploring cross-language WASM development
- Building secure, sandboxed API integrations

Each example includes comprehensive documentation, local testing instructions, and production-ready code patterns.

## Available Examples

### 🌦️ Weather Plugin
Get real-time weather information from OpenWeatherMap API.

**Available in 5 languages:**
- [**Rust**](rust/weather/) - High-performance with `waki` HTTP client
- [**Go**](go/weather/) - TinyGo compilation with WASI HTTP bindings
- [**Python**](python/weather/) - Direct WASI bindings with `componentize-py`
- [**JavaScript**](javascript/weather/) - Native `fetch()` API with ComponentizeJS
- [**TypeScript**](typescript/weather/) - Type-safe development with full IDE support

**Features:**
- Fetches current weather data for any city
- Supports metric and imperial units
- Secure API key management via environment variables
- Robust error handling for network failures

### 💱 Exchange Rate Plugin
Real-time currency conversion and exchange rate information.

**Available in:**
- [**Rust**](rust/exchange-rate/) - Multiple API endpoints with fallback support

**Features:**
- Get current exchange rates for any base currency
- Convert amounts between different currencies
- List all supported currencies
- Automatic fallback to secondary API if primary fails
- No API key required - uses free currency data sources

### 📚 ArXiv Plugin
Search and download academic papers from arXiv repository.

**Available in:**
- [**Rust**](rust/arxiv/) - Atom/RSS feed parsing with PDF downloads

**Features:**
- Search arXiv for academic papers
- Download paper PDFs directly
- Structured metadata including authors, abstracts, and categories
- Efficient feed parsing with `feed-rs`

## Technology Stack

### WebAssembly Component Model
All plugins use the WebAssembly Component Model with WASI 0.2, providing:
- **Security**: Capability-based sandboxing with fine-grained permissions
- **Portability**: Run on any WASI 0.2 runtime (wasmtime, wasmer, browser)
- **Composition**: Plugins can import/export interfaces between components
- **Language Agnostic**: WIT interfaces enable seamless interop

### Language-Specific Toolchains

#### Rust
- `wasm32-wasip2` target for optimal WASM output
- `wit-bindgen` for Component Model integration
- `waki` for WASI-native HTTP client
- Zero-cost abstractions with minimal binary size

#### Go
- TinyGo compiler for efficient WASM binaries
- `wit-bindgen-go` for type-safe bindings
- Direct WASI HTTP interface access
- Go-idiomatic patterns adapted for WASM

#### Python
- `componentize-py` for Python-to-WASM compilation
- Direct WASI HTTP bindings without external libraries
- Native JSON handling with built-in libraries
- Dataclasses and enums for type safety

#### JavaScript
- ComponentizeJS with StarlingMonkey runtime
- Built on SpiderMonkey (Firefox's JS engine)
- Native `fetch()` API support
- ES modules and modern JavaScript features

#### TypeScript
- Full type safety with compile-time checks
- Two-stage compilation: TypeScript → JavaScript → WASM
- IDE support with IntelliSense and autocomplete
- Type-safe JSON serialization

## Getting Started

### Prerequisites

#### Noorle CLI Installation
Install the Noorle CLI to build and deploy plugins:

**Option 1: Quick Install (Recommended)**
```bash
curl -L cli.noorle.dev | sh
```

**Option 2: Download Platform-Specific Binary**
Download the latest release for your platform from [GitHub Releases](https://github.com/noorle/cli-releases/releases/latest).

See the [CLI Reference](https://noorle.com/docs/reference/cli) for detailed documentation.

#### WebAssembly Toolset
To streamline development experience, Noorle plugins use a standard set of WASM tools. These are automatically installed when you run `noorle plugin prepare`:

- **wasmtime** - WebAssembly runtime for local testing
- **wkg** - WIT package manager for dependency management
- **wasm-tools** - WebAssembly component utilities
- **Rust toolchain** - Required for the above tools (they're built in Rust)

These tools are used by the build scripts across all language templates to ensure consistent WASM component generation.

### Quick Start

1. Clone the repository:
```bash
git clone https://github.com/noorle/plugin-examples
cd plugin-examples
```

2. Choose an example and language:
```bash
cd rust/weather
```

3. Prepare development environment:
```bash
# Install required WASM tools (one-time setup)
noorle plugin prepare

# Or check if tools are already installed
noorle plugin prepare --check
```

The `prepare` command runs the template's `prepare.sh` script which:
- Checks for required development tools
- Installs missing dependencies (with your permission)
- Configures your environment for WASM development
- Ensures consistent tooling across all templates

4. Configure environment variables (if needed):
```bash
cp .env.example .env
# Add your API key to .env
```

5. Build the plugin:
```bash
noorle plugin build
```

This runs the template's `build.sh` script which:
- Compiles your code to WebAssembly
- Generates Component Model bindings
- Produces `dist/plugin.wasm`
- Creates a `.npack` archive for deployment

6. Test locally:
```bash
# Example for weather plugin
wasmtime run --wasi http --env OPENWEATHER_API_KEY=your_key \
  --invoke 'check-weather("Austin", "metric")' dist/plugin.wasm
```

7. Deploy to Noorle:
```bash
# Authenticate first
noorle login

# Deploy the plugin
noorle plugin deploy

# Or build and deploy in one step
noorle plugin publish
```

## Noorle CLI Workflow

The Noorle CLI provides a streamlined workflow for plugin development:

### Creating New Plugins
```bash
# List available templates
noorle plugin list-templates

# Create from template
noorle plugin init my-plugin --template rust

# Interactive template selection
noorle plugin init my-plugin
```

### Development Commands
```bash
# Check/install dependencies
noorle plugin prepare         # Interactive installation
noorle plugin prepare --check  # Check only
noorle plugin prepare --ci     # Non-interactive for CI/CD

# Build plugin
noorle plugin build           # Runs build.sh, creates WASM

# Validate configuration
noorle plugin validate noorle.yaml

# Create deployment package
noorle plugin pack            # Creates .npack archive
```

### Deployment Commands
```bash
# Authentication
noorle login                  # OAuth device flow
noorle logout                 # Clear tokens

# Deploy to platform
noorle plugin deploy          # Deploy existing .npack
noorle plugin publish         # Build + deploy
```

## Project Structure

Each plugin follows a consistent structure:
```
language/plugin-name/
├── src/ or app.*        # Main implementation
├── wit/
│   └── world.wit        # Component interface definition
├── noorle.yaml          # Plugin permissions and config
├── prepare.sh           # Dependency setup script
├── build.sh             # Build script
├── .env.example         # Environment template
├── README.md            # Detailed documentation
└── dist/
    ├── plugin.wasm      # Compiled WASM component
    └── *.npack          # Deployment archive
```

### Key Files Explained

- **prepare.sh**: Checks and installs development tools (wasmtime, wkg, wasm-tools)
- **build.sh**: Language-specific build script that produces WASM output
- **world.wit**: WebAssembly Interface Types definition for your plugin's API
- **noorle.yaml**: Specifies permissions, environment variables, and metadata

## Key Concepts Demonstrated

### HTTP Client Integration
- Making external API calls from sandboxed WASM components
- Language-specific HTTP client patterns
- Timeout handling and connection management
- Request/response streaming

### Environment Configuration
- Secure API key management
- Configuration through environment variables
- Capability-based permissions in `noorle.yaml`

### Error Handling
- Robust patterns for network failures
- API error handling
- Result types and error propagation
- Graceful degradation with fallbacks

### JSON Processing
- Parsing and serializing external API data
- Type-safe data structures
- Handling optional fields and null values

### Component Interface Design
- Clean WIT interface definitions
- Type mapping between languages and Component Model
- Export functions with documented parameters
- Result types for error handling

## Learning Path

1. **Start with Weather Plugin**: Learn HTTP integration and basic patterns
2. **Explore Exchange Rate**: Understand fallback strategies and data caching
3. **Study ArXiv Plugin**: Master feed parsing and binary file handling
4. **Compare Languages**: See how different languages approach the same problem

## Best Practices

### Security
- Never hardcode API keys or secrets
- Use environment variables for configuration
- Specify minimal permissions in `noorle.yaml`
- Validate all external data

### Performance
- Choose appropriate language for use case
- Optimize binary size (especially with TinyGo/Rust)
- Implement caching where appropriate
- Use streaming for large responses

### Error Handling
- Always return Result types
- Provide meaningful error messages
- Implement retry logic for transient failures
- Add fallback mechanisms for critical services

### Development
- Write comprehensive tests
- Document all exported functions
- Follow language-specific idioms
- Use type safety where available

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Adding New Examples
1. Choose a practical use case
2. Implement in at least one language
3. Include comprehensive README
4. Add tests and documentation
5. Follow existing patterns and structure

## Resources

- [Noorle CLI Reference](https://noorle.com/docs/reference/cli)
- [WebAssembly Component Model](https://github.com/WebAssembly/component-model)
- [WASI 0.2 Specification](https://github.com/WebAssembly/WASI)
- [WIT Interface Types](https://github.com/WebAssembly/component-model/blob/main/design/mvp/WIT.md)

## License

MIT License with Additional Terms for Noorle Platform

Copyright (c) 2024 Noorle

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

**Additional Terms for Noorle Platform Integration:**
- These examples are optimized for and officially supported on the Noorle platform
- When deploying to Noorle, plugins must comply with Noorle's Terms of Service
- The Noorle team may use these examples for platform documentation and promotion

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Support

- [GitHub Issues](https://github.com/noorle/plugin-examples/issues)
- [Noorle Documentation](https://noorle.com/docs)