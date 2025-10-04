# News Plugin (Rust) - Noorle Example

A reference implementation demonstrating news API integration in Noorle plugins using Rust and the WebAssembly Component Model with WASI 0.2.

## Why This Example Matters

This news plugin showcases real-world patterns for building media-driven Noorle plugins:

- **News API Integration**: Shows how to integrate with NewsAPI.org for real-time news content
- **Structured Type Handling**: Demonstrates Component Model record types for complex data structures
- **Environment Variable Handling**: Secure configuration management for API keys in sandboxed environments
- **Error Handling**: Robust patterns for API rate limits, authentication failures, and network errors
- **JSON Processing**: Parsing external API responses and transforming to structured types
- **Component Interface Design**: Clean, type-safe APIs using WIT (WebAssembly Interface Types)

## Architecture & Technology Choices

**WebAssembly Component Model with WASI 0.2** provides secure, portable sandboxing with standardized system interfaces, making plugins safe to run anywhere while maintaining access to essential system capabilities.

**Rust + `waki` HTTP Client:**
- `waki` is designed specifically for WASI environments with minimal overhead
- Built-in support for WASI HTTP interfaces without complex async runtime requirements
- Type-safe HTTP client that integrates seamlessly with Rust's error handling
- Excellent WASM binary size optimization

**Why Rust for WASM:**
- Excellent WASM toolchain with `wasm32-wasip2` target
- Zero-cost abstractions compile to efficient WASM
- Strong type system prevents common plugin development errors
- Mature ecosystem with `wit-bindgen` for Component Model integration

## Component Model Benefits

- **Type Safety**: WIT record types provide compile-time guarantees for data structures
- **Security**: Capability-based permissions limit network access to specified hosts only
- **Portability**: Runs on any WASI 0.2 runtime (wasmtime, wasmer, browser, etc.)
- **Language Agnostic**: WIT interfaces allow seamless interop between different language implementations
- **No Serialization Overhead**: Structured types are passed directly without JSON encoding

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
# Test news search
wasmtime run --wasi http --env NEWSAPI_API_KEY=your_api_key_here \
  --invoke 'search-news("artificial intelligence")' dist/plugin.wasm

# Search for specific topics
wasmtime run --wasi http --env NEWSAPI_API_KEY=your_api_key_here \
  --invoke 'search-news("climate change")' dist/plugin.wasm
```

### Environment Setup
```bash
# Copy environment template
cp .env.example .env

# Add your NewsAPI.org API key
echo "NEWSAPI_API_KEY=your_actual_api_key" > .env
```

Get your free API key from [NewsAPI.org](https://newsapi.org).

## Project Structure

```
news/
├── src/
│   ├── lib.rs           # Main plugin implementation
│   └── types.rs         # Data structures for NewsAPI responses
├── wit/
│   └── world.wit        # Component interface definition
├── Cargo.toml           # Rust dependencies and metadata
├── noorle.yaml          # Plugin permissions and configuration
├── build.sh             # Build script (used by noorle CLI)
└── dist/                # Build output (created after build)
    └── plugin.wasm      # Compiled WASM component
```

## Key Dependencies

```toml
[dependencies]
wit-bindgen = "0.46.0"    # Component Model bindings generation
anyhow = "1.0"            # Error handling
serde = { version = "1.0", features = ["derive"] }  # JSON deserialization
serde_json = "1.0"        # JSON parsing for API responses
waki = "0.5.1"            # WASI HTTP client
urlencoding = "2.1"       # URL encoding for API parameters
```

## API Reference

### `search-news(query: string) -> result<news-response, string>`

Fetches news articles matching the specified search query.

**Parameters:**
- `query`: Search query for news articles. Can include keywords, phrases, or topics (e.g., "artificial intelligence", "climate change", "technology")

**Returns:**
Success: `news-response` record containing:
```
record news-response {
  articles: list<article>
}

record article {
  title: option<string>,
  description: option<string>,
  url: option<string>,
  source: option<source>
}

record source {
  name: option<string>
}
```

Example output:
```
news-response {
  articles: [
    {
      title: "Breaking: New AI Model Achieves Human-Level Performance",
      description: "Researchers at a leading tech company have developed a new AI model that demonstrates human-level performance across multiple benchmarks.",
      url: "https://example.com/news/ai-breakthrough",
      source: {
        name: "Tech News Today"
      }
    },
    {
      title: "AI Ethics Panel Discusses Future Regulations",
      description: "Industry leaders gather to address growing concerns about AI safety and governance.",
      url: "https://example.com/news/ai-ethics",
      source: {
        name: "Science Daily"
      }
    }
  ]
}
```

Error: String describing what went wrong

**Possible Errors:**
- `"NEWSAPI_API_KEY environment variable not set"`: API key not configured
- `"Invalid NewsAPI API key"`: Authentication failed (HTTP 401)
- `"NewsAPI rate limit exceeded. Please try again later."`: Rate limit hit (HTTP 429)
- `"Search query cannot be empty"`: Empty query provided
- `"News search failed: ..."`: Network or parsing errors

## HTTP Client Implementation Details

### API Integration Pattern

```rust
use waki::Client;

let response = Client::new()
    .get(&request_url)
    .connect_timeout(Duration::from_secs(TIMEOUT_SECS))
    .header("x-api-key", &api_key)
    .header("User-Agent", "Mozilla/5.0 (compatible; noorle/1.0)")
    .send()
    .context("Failed to send request to NewsAPI")?;
```

**Why This Pattern:**
- Direct integration with WASI HTTP interfaces
- Explicit timeout handling (30 seconds)
- Custom headers for API authentication
- Built-in error context for debugging

**Error Handling Patterns:**
```rust
// Check HTTP status codes
let status = response.status_code();
if status == 429 {
    anyhow::bail!("NewsAPI rate limit exceeded. Please try again later.");
}
if status == 401 {
    anyhow::bail!("Invalid NewsAPI API key");
}
```

## Learning Outcomes

By studying this example, developers learn:

1. **News API Integration**: How to integrate with NewsAPI.org for real-time news content
2. **Structured Type Systems**: Using WIT records instead of JSON strings for type safety
3. **Environment Configuration**: Secure handling of API keys and configuration in WASM
4. **Rate Limit Handling**: Graceful degradation when API limits are reached
5. **HTTP Error Handling**: Comprehensive error handling for authentication and network failures
6. **Data Transformation**: Converting external API formats to clean, structured Component Model types

This example serves as a foundation for building news aggregators, content monitoring tools, media search engines, and real-time information plugins.
