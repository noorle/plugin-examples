# Weather Plugin (Rust) - Noorle Example

A reference implementation demonstrating HTTP API integration in Noorle plugins using Rust and the WebAssembly Component Model with WASI 0.2.

## Why This Example Matters

This weather plugin showcases real-world patterns for building production-ready Noorle plugins:

- **HTTP Client Integration**: Shows how to make external API calls from WASM components
- **Environment Variable Handling**: Secure configuration management in sandboxed environments
- **Error Handling**: Robust patterns for network failures and API errors
- **JSON Processing**: Parsing and serializing data from external services
- **Component Interface Design**: Clean, documented APIs using WIT (WebAssembly Interface Types)

## Architecture & Technology Choices

**WebAssembly Component Model with WASI 0.2** provides secure, portable sandboxing with standardized system interfaces, making plugins safe to run anywhere while maintaining access to essential system capabilities.

**Rust + `waki` HTTP Client:**
- `waki` is designed specifically for WASI environments, unlike `reqwest` which has compatibility issues
- Minimal overhead and excellent WASM binary size optimization
- Built-in support for WASI HTTP interfaces without complex async runtime requirements
- Type-safe HTTP client that integrates seamlessly with Rust's error handling

**Why Rust for WASM:**
- Excellent WASM toolchain with `wasm32-wasip2` target
- Zero-cost abstractions compile to efficient WASM
- Strong type system prevents common plugin development errors
- Mature ecosystem with `wit-bindgen` for Component Model integration

## HTTP Client Implementation Deep Dive

### Library Choice: `waki` vs Alternatives

```rust
use waki::Client;

let response = Client::new()
    .get(&request_url)
    .connect_timeout(Duration::from_secs(TIMEOUT_SECS))
    .header("User-Agent", "Mozilla/5.0 (compatible; noorle/1.0)")
    .send()
    .map_err(|e| Error::msg(format!("HTTP request failed: {}", e)))?;
```

**Why `waki`:**
- Purpose-built for WASI HTTP without async complexity
- Smaller WASM binaries compared to `reqwest`
- Direct integration with WASI HTTP interfaces
- Synchronous API that's easier to reason about in WASM contexts

**WASI HTTP Integration:**
- Uses the standardized `wasi:http` interface for network access
- Capability-based permissions ensure plugins only access allowed hosts
- Built-in timeout and error handling through WASI runtime

**Error Handling Patterns:**
```rust
let status = response.status_code();
if !(200..300).contains(&status) {
    return Err(Error::msg(format!("HTTP error: status code {}", status)));
}
```

## Component Model Benefits

- **Security**: Capability-based permissions limit network access to specified hosts only
- **Portability**: Runs on any WASI 0.2 runtime (wasmtime, wasmer, browser, etc.)
- **Composition**: Plugins can import/export interfaces to work with other components
- **Language Agnostic**: WIT interfaces allow seamless interop between different language implementations

## Development & Testing

### Build and Deploy
```bash
# Build the plugin (creates WASM component)
noorle plugin build

# Deploy to Noorle platform
noorle plugin deploy
```

### Local Testing with wasmtime
```bash
# Test with metric units
wasmtime run --wasi http --env OPENWEATHER_API_KEY=your_api_key_here \
  --invoke 'check-weather("Austin", metric)' dist/plugin.wasm

# Test with imperial units
wasmtime run --wasi http --env OPENWEATHER_API_KEY=your_api_key_here \
  --invoke 'check-weather("Austin", imperial)' dist/plugin.wasm
```

**Note:** The `unit` parameter (metric/imperial) is an enum type and should be passed without quotes in the wasmtime invoke command. This differs from string parameters which require quotes.

### Environment Setup
```bash
# Copy environment template
cp .env.example .env

# Add your OpenWeatherMap API key
echo "OPENWEATHER_API_KEY=your_actual_api_key" > .env
```

Get your API key from [OpenWeatherMap](https://openweathermap.org/api).

## Project Structure

```
weather/
├── src/
│   └── lib.rs           # Main plugin implementation
├── wit/
│   └── world.wit        # Component interface definition
├── Cargo.toml           # Rust dependencies and metadata
├── noorle.yaml          # Plugin permissions and configuration
├── .env.example         # Environment variable template
├── build.sh             # Build script (used by noorle CLI)
└── dist/                # Build output (created after build)
    └── plugin.wasm      # Compiled WASM component
```

## Key Dependencies

```toml
[dependencies]
wit-bindgen = "0.46.0"    # Component Model bindings generation
anyhow = "1.0"            # Error handling
serde = { version = "1.0", features = ["derive"] }  # JSON serialization
serde_json = "1.0"        # JSON parsing
waki = "0.5"              # WASI HTTP client
urlencoding = "2.1"       # URL encoding for API parameters
```

## API Reference

### `check-weather(location: string, unit: unit) -> result<weather-response, string>`

Fetches current weather information for a specified location.

**Parameters:**
- `location`: City name or "City,CountryCode" format (e.g., "Austin", "London,UK")
- `unit`: Temperature unit enum - `metric` (Celsius) or `imperial` (Fahrenheit)

**Returns:**
Success: `weather-response` record containing:
```
record weather-response {
  location: string,
  temperature: f64,
  feels-like-temperature: f64,
  wind-speed: option<f64>,
  wind-degrees: option<u32>,
  humidity: option<u32>,
  unit: unit,
  weather-conditions: list<string>
}
```

Example output:
```json
{
  "location": "Austin",
  "temperature": 25.3,
  "feels_like_temperature": 27.1,
  "wind_speed": 3.2,
  "wind_degrees": 180,
  "humidity": 65,
  "unit": "metric",
  "weather_conditions": ["clear sky"]
}
```

Error: String describing what went wrong

## Learning Outcomes

By studying this example, developers learn:

1. **HTTP Client Patterns**: How to integrate external APIs in WASM components
2. **Environment Configuration**: Secure handling of API keys and configuration
3. **Error Handling**: Robust patterns for network and parsing errors
4. **Component Interfaces**: Designing clean, documented APIs with WIT
5. **WASI Integration**: Leveraging system interfaces for real-world functionality
6. **Rust Best Practices**: Idiomatic Rust patterns optimized for WASM targets

This example serves as a foundation for building any plugin that needs external API integration, from weather services to database connectors to AI model APIs.