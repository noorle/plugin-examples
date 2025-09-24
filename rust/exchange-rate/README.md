# Exchange Rate Plugin (Rust) - Noorle Example

A Rust WebAssembly plugin for the Noorle platform that provides real-time exchange rates and currency conversion capabilities.

## Features

- **Exchange Rates**: Get current exchange rates for any base currency with optional filtering
- **Currency Conversion**: Convert amounts between different currencies using live rates
- **Currency List**: Retrieve all supported currencies with their full names
- **Robust Error Handling**: Uses `result<string, string>` for type-safe error handling
- **Fallback Support**: Automatic fallback to secondary API if primary fails
- **Fast & Efficient**: Built with Rust for optimal WASM performance

## Why This Example Matters

This exchange rate plugin demonstrates essential patterns for building financial/data-driven Noorle plugins:

- **Multiple API Endpoints**: Shows how to implement fallback strategies for reliability
- **Data Caching**: Efficient handling of rate data to minimize API calls
- **Precision Handling**: Working with floating-point currency calculations
- **Error Recovery**: Graceful fallback when primary data sources fail

## Architecture & Technology Choices

**WebAssembly Component Model with WASI 0.2** provides secure, portable sandboxing with standardized system interfaces.

**Key Design Patterns:**
- **Fallback API Strategy**: Primary and secondary endpoints for high availability
- **Free API Usage**: No API keys required - uses open currency data sources
- **Stateless Operations**: Each function call is independent for scalability

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
# Test exchange rate retrieval
wasmtime run --wasi http \
  --invoke 'get-exchange-rates("usd", "eur,gbp,jpy")' dist/plugin.wasm

# Test currency conversion
wasmtime run --wasi http \
  --invoke 'convert-currency("usd", "eur", 100.0)' dist/plugin.wasm

# Test listing all currencies
wasmtime run --wasi http \
  --invoke 'list-currencies()' dist/plugin.wasm
```

## Project Structure

```
exchange-rate/
├── src/
│   ├── lib.rs           # Main plugin implementation
│   └── types.rs         # Data structures for exchange rates
├── wit/
│   └── world.wit        # Component interface definition
├── Cargo.toml           # Rust dependencies and metadata
├── noorle.yaml          # Plugin permissions and configuration
├── build.sh             # Build script (used by noorle CLI)
└── dist/                # Build output (created after build)
    └── plugin.wasm      # Compiled WASM component
```

## API Reference

### `get-exchange-rates(base-currency: string, target-currencies: string) -> result<string, string>`

Get current exchange rates for a base currency.

**Parameters:**
- `base-currency`: Base currency code (e.g., "usd", "eur", "gbp")
- `target-currencies`: Optional comma-separated list of target currencies to filter results

**Returns:**
Success: JSON string containing exchange rate data:
```json
{
  "base_currency": "usd",
  "rates": {
    "eur": 0.92,
    "gbp": 0.79,
    "jpy": 149.50
  },
  "last_updated": "2025-09-23"
}
```

Error: String describing what went wrong

### `convert-currency(from-currency: string, to-currency: string, amount: f64) -> result<string, string>`

Convert an amount from one currency to another.

**Parameters:**
- `from-currency`: Source currency code (e.g., "usd", "eur", "gbp")
- `to-currency`: Target currency code (e.g., "usd", "eur", "gbp")
- `amount`: Amount to convert

**Returns:**
Success: JSON string containing conversion result:
```json
{
  "from_currency": "usd",
  "to_currency": "eur",
  "amount": 100.0,
  "converted_amount": 92.0,
  "exchange_rate": 0.92,
  "last_updated": "2025-09-23"
}
```

Error: String describing what went wrong

### `list-currencies() -> result<string, string>`

List all supported currencies.

**Returns:**
Success: JSON string containing supported currencies:
```json
{
  "currencies": {
    "usd": "US Dollar",
    "eur": "Euro",
    "gbp": "British Pound",
    "jpy": "Japanese Yen"
  }
}
```

Error: String describing what went wrong

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

## Learning Outcomes

By studying this example, developers learn:

1. **Fallback Strategies**: Implementing reliable API access with multiple endpoints
2. **Financial Data Handling**: Working with currency precision and conversions
3. **Caching Patterns**: Efficient data management in stateless components
4. **Free API Integration**: Building valuable services without API key requirements
5. **Error Recovery**: Graceful degradation when services are unavailable

This example serves as a foundation for building financial tools, data aggregation services, and real-time information plugins.