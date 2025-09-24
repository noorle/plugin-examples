# Weather Plugin (Go) - Noorle Example

A reference implementation demonstrating HTTP API integration in Noorle plugins using Go, TinyGo, and the WebAssembly Component Model with WASI 0.2.

## Why This Example Matters

This weather plugin showcases real-world patterns for building production-ready Noorle plugins:

- **HTTP Client Integration**: Shows how to make external API calls from WASM components using Go
- **Environment Variable Handling**: Secure configuration management in sandboxed environments
- **Error Handling**: Robust patterns for network failures and API errors in Go
- **JSON Processing**: Efficient JSON parsing and serialization using Go's standard library
- **Component Interface Design**: Clean, documented APIs using WIT (WebAssembly Interface Types)

## Architecture & Technology Choices

**WebAssembly Component Model with WASI 0.2** provides secure, portable sandboxing with standardized system interfaces, making plugins safe to run anywhere while maintaining access to essential system capabilities.

**Go + TinyGo + WASI HTTP:**
- TinyGo compiles Go to highly optimized WASM with WASI Preview 2 support
- Uses generated Go bindings from WIT interfaces via `wit-bindgen-go`
- Direct integration with WASI HTTP interfaces for minimal overhead
- Leverages Go's excellent HTTP and JSON standard library patterns

**Why TinyGo for WASM:**
- Produces much smaller WASM binaries compared to standard Go compiler
- Built-in WASI Preview 2 support with `wasip2` target
- Optimized for embedded/constrained environments like WASM
- Maintains Go language compatibility while targeting WASM efficiently

**WIT Bindings Generation:**
- `wit-bindgen-go` generates type-safe Go bindings from WIT interface definitions
- Automatic mapping between Go types and Component Model types
- Zero-cost abstractions for WASI interface access

## HTTP Client Implementation Deep Dive

### TinyGo + WASI HTTP Pattern

```go
func makeHTTPRequest(pathWithQuery string) ([]byte, error) {
    // Create headers using WASI HTTP types
    headers := types.NewFields()
    userAgent := cm.ToList([]uint8("Mozilla/5.0 (compatible; noorle/1.0"))
    headers.Append("User-Agent", types.FieldValue(userAgent))

    // Create the request
    request := types.NewOutgoingRequest(headers)
    request.SetMethod(types.MethodGet())
    request.SetScheme(cm.Some(types.SchemeHTTPS()))
    request.SetAuthority(cm.Some(OPENWEATHER_HOST))
    request.SetPathWithQuery(cm.Some(pathWithQuery))

    // Send request through WASI
    futureResponse := outgoinghandler.Handle(request, cm.None[types.RequestOptions]())

    // Poll and wait for response
    pollable := futureResponse.Subscribe()
    poll.Poll(cm.ToList([]types.Pollable{pollable}))

    // Process response...
}
```

**Why TinyGo + WASI HTTP:**
- Direct access to WASI HTTP capabilities without external dependencies
- Type-safe bindings generated from WIT interface definitions
- Minimal binary size overhead
- Familiar Go patterns adapted for WASM environments

**WASI HTTP Integration:**
- Uses the standardized `wasi:http` interface through generated Go bindings
- No external HTTP library dependencies required
- Built-in timeout and connection management through WASI runtime
- Automatic memory management optimized for WASM

**Error Handling Patterns:**
```go
// Go-idiomatic error handling adapted for WASI
if futureResponseResult.IsErr() {
    return nil, fmt.Errorf("failed to handle request: %v", futureResponseResult.Err())
}

response := responseResult.OK()
status := response.Status()
if status < 200 || status >= 300 {
    return nil, fmt.Errorf("HTTP error: status code %d", status)
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
  --invoke 'check-weather("Austin", "metric")' dist/plugin.wasm

# Test with imperial units
wasmtime run --wasi http --env OPENWEATHER_API_KEY=your_api_key_here \
  --invoke 'check-weather("Austin", "imperial")' dist/plugin.wasm
```

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
├── main.go              # Main plugin implementation
├── wit/
│   └── world.wit        # Component interface definition
├── go.mod               # Go module definition
├── noorle.yaml          # Plugin permissions and configuration
├── .env.example         # Environment variable template
├── build.sh             # Build script (used by noorle CLI)
├── gen/                 # Generated WIT bindings (created during build)
└── dist/                # Build output (created after build)
    └── plugin.wasm      # Compiled WASM component
```

## Key Dependencies

```go
require (
    go.bytecodealliance.org/cm v0.3.0  // Component Model runtime support
)
```

**Build Tools:**
- `wit-bindgen-go` - Generates Go bindings from WIT definitions
- `wkg` - WebAssembly package manager for fetching WIT dependencies
- `TinyGo` - Go compiler for WebAssembly with WASI support

## API Reference

### `check-weather(location: string, unit: string) -> string`

Fetches current weather information for a specified location.

**Parameters:**
- `location`: City name or "City,CountryCode" format (e.g., "Austin", "London,UK")
- `unit`: Temperature unit - "metric" (Celsius) or "imperial" (Fahrenheit)

**Returns:**
JSON string containing weather data or error:

Success:
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

Error:
```json
{
  "error": "Error message describing what went wrong"
}
```

## Go Implementation Features

### Struct-Based Response Modeling
```go
type WeatherResponse struct {
    Location             string   `json:"location"`
    Temperature          float64  `json:"temperature"`
    FeelsLikeTemperature float64  `json:"feels_like_temperature"`
    WindSpeed            *float64 `json:"wind_speed,omitempty"`
    WindDegrees          *int     `json:"wind_degrees,omitempty"`
    Humidity             *int     `json:"humidity,omitempty"`
    Unit                 string   `json:"unit"`
    WeatherConditions    []string `json:"weather_conditions"`
}
```

### WASI Stream Reading
```go
for {
    readResult := stream.BlockingRead(65536)
    if readResult.IsErr() {
        err := readResult.Err()
        if err.Closed() {
            break
        }
        return nil, fmt.Errorf("failed to read response body: %v", err)
    }
    body = append(body, readResult.OK().Slice()...)
}
```

### Environment Variable Access
```go
envVars := environment.GetEnvironment().Slice()
for _, env := range envVars {
    if env[0] == "OPENWEATHER_API_KEY" {
        apiKey = env[1]
        break
    }
}
```

## Learning Outcomes

By studying this example, developers learn:

1. **Go in WASM**: How to use Go and TinyGo for WASM component development
2. **WASI HTTP Bindings**: Direct integration with WASI HTTP interfaces
3. **WIT Code Generation**: Using `wit-bindgen-go` for type-safe bindings
4. **Error Handling**: Go-idiomatic patterns adapted for WASM environments
5. **Component Development**: Building reusable WASM components with Go

This example serves as a foundation for building any plugin that needs external API integration, demonstrating how Go's simplicity and efficiency translate perfectly to the WebAssembly Component Model ecosystem.