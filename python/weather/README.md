# Weather Plugin (Python) - Noorle Example

A reference implementation demonstrating HTTP API integration in Noorle plugins using Python and the WebAssembly Component Model with WASI 0.2.

## Why This Example Matters

This weather plugin showcases real-world patterns for building production-ready Noorle plugins:

- **HTTP Client Integration**: Shows how to make external API calls from WASM components using Python
- **Environment Variable Handling**: Secure configuration management in sandboxed environments
- **Error Handling**: Robust patterns for network failures and API errors in Python
- **JSON Processing**: Native Python patterns for parsing and serializing API data
- **Component Interface Design**: Clean, documented APIs using WIT (WebAssembly Interface Types)

## Architecture & Technology Choices

**WebAssembly Component Model with WASI 0.2** provides secure, portable sandboxing with standardized system interfaces, making plugins safe to run anywhere while maintaining access to essential system capabilities.

**Python + WASI HTTP Bindings:**
- Uses the official `componentize-py` for Python-to-WASM compilation
- Direct integration with WASI HTTP interfaces through generated bindings
- Leverages Python's excellent HTTP and JSON handling capabilities
- Familiar Python patterns in a sandboxed WASM environment

**Why Python for WASM:**
- Rapid development with familiar syntax and libraries
- Excellent JSON and HTTP handling with built-in libraries
- `componentize-py` provides seamless Component Model integration
- Dynamic nature allows for flexible API response handling

## HTTP Client Implementation Deep Dive

### WASI HTTP Integration Pattern

```python
def make_http_request(url: str, headers_dict: dict) -> bytes:
    # Create headers using WASI HTTP types
    headers = http_types.Fields()
    for key, value in headers_dict.items():
        headers.append(key, value.encode())

    # Create outgoing request
    request = http_types.OutgoingRequest(headers)
    request.set_method(http_types.Method_Get())
    request.set_scheme(http_types.Scheme_Https())
    request.set_authority(OPENWEATHER_ENDPOINT)

    # Send request through WASI
    response = outgoing_handler.handle(request, None)
    response_pollable = response.subscribe()
    poll_module.poll([response_pollable])
```

**Why Direct WASI Bindings:**
- No dependency on external HTTP libraries like `requests`
- Direct access to WASI HTTP capabilities
- Optimal WASM binary size
- Full control over request/response handling

**WASI HTTP Integration:**
- Uses low-level `wasi:http` interfaces through generated Python bindings
- Polling-based async pattern that works in WASM environments
- Stream-based response reading for memory efficiency
- Built-in error handling through WASI result types

**Error Handling Patterns:**
```python
# Handle nested Result types from WASI
if isinstance(result, Err):
    raise Exception(f"Failed to get response: {result.value}")

inner_result = result.value if isinstance(result, Ok) else result
if isinstance(inner_result, Err):
    raise Exception(f"Request failed with error code: {inner_result.value}")
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
├── app.py               # Main plugin implementation
├── wit/
│   └── world.wit        # Component interface definition
├── pyproject.toml       # Python dependencies and metadata
├── noorle.yaml          # Plugin permissions and configuration
├── .env.example         # Environment variable template
├── build.sh             # Build script (used by noorle CLI)
└── dist/                # Build output (created after build)
    └── plugin.wasm      # Compiled WASM component
```

## Key Dependencies

```toml
[project]
dependencies = [
    "componentize-py==0.17.2",  # Python-to-WASM compilation
]
```

**Runtime Dependencies:**
- `wit_world` - Generated bindings from WIT interface definitions
- `wasi:http` - HTTP client capabilities through WASI
- `wasi:cli/environment` - Environment variable access
- `json` - Built-in JSON processing
- `urllib.parse` - URL encoding utilities

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

## Python Implementation Features

### Data Classes for Type Safety
```python
@dataclass
class WeatherResponse:
    location: str
    temperature: float
    feels_like_temperature: float
    wind_speed: Optional[float]
    wind_degrees: Optional[int]
    humidity: Optional[int]
    unit: str
    weather_conditions: List[str]
```

### Enums for Valid Options
```python
class Unit(str, Enum):
    METRIC = "metric"
    IMPERIAL = "imperial"
```

### Stream-Based Response Reading
```python
chunks = []
while True:
    body_chunk = body_stream.blocking_read(8192)
    if len(body_chunk) == 0:
        break
    chunks.append(body_chunk)
```

## Learning Outcomes

By studying this example, developers learn:

1. **Python in WASM**: How to use Python for WASM component development
2. **WASI HTTP Bindings**: Direct integration with WASI HTTP interfaces
3. **Error Handling**: Robust patterns for handling WASI Result types
4. **Environment Configuration**: Secure handling of API keys and configuration
5. **Component Development**: Building reusable WASM components with Python

This example serves as a foundation for building any plugin that needs external API integration, demonstrating how Python's simplicity and power can be leveraged in the WebAssembly Component Model ecosystem.