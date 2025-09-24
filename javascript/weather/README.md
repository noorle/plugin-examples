# Weather Plugin (JavaScript) - Noorle Example

A reference implementation demonstrating HTTP API integration in Noorle plugins using JavaScript, ComponentizeJS, and the WebAssembly Component Model with WASI 0.2.

## Why This Example Matters

This weather plugin showcases real-world patterns for building production-ready Noorle plugins:

- **HTTP Client Integration**: Shows how to make external API calls from WASM components using JavaScript
- **Environment Variable Handling**: Secure configuration management in sandboxed environments
- **Error Handling**: Robust patterns for network failures and API errors in JavaScript
- **JSON Processing**: Native JavaScript patterns for parsing and serializing API data
- **Component Interface Design**: Clean, documented APIs using WIT (WebAssembly Interface Types)

## Architecture & Technology Choices

**WebAssembly Component Model with WASI 0.2** provides secure, portable sandboxing with standardized system interfaces, making plugins safe to run anywhere while maintaining access to essential system capabilities.

**JavaScript + ComponentizeJS + StarlingMonkey:**
- ComponentizeJS compiles JavaScript to WASM components using the StarlingMonkey runtime
- Built on SpiderMonkey (Firefox's JavaScript engine) optimized for WASM
- Native `fetch()` API support for familiar HTTP client patterns
- ES modules and modern JavaScript features in a sandboxed environment

**Why JavaScript for WASM:**
- Familiar development experience with modern JavaScript
- Native JSON handling without external libraries
- Fast iteration and debugging during development
- Access to `fetch()` API that developers already know

## HTTP Client Implementation Deep Dive

### Fetch API Pattern

```javascript
async function getWeather(apiKey, params) {
    const unitQuery = params.unit;
    const encodedLocation = encodeURIComponent(params.location);

    const requestUrl = `${OPENWEATHER_ENDPOINT}?q=${encodedLocation}&appid=${apiKey}&units=${unitQuery}`;

    try {
        const response = await fetch(requestUrl, {
            method: 'GET',
            headers: {
                'User-Agent': 'Mozilla/5.0 (compatible; noorle/1.0)'
            }
        });

        if (!response.ok) {
            throw new Error(`HTTP error: status code ${response.status}`);
        }

        const weatherData = await response.json();
        return processWeatherData(weatherData, params);
    } catch (error) {
        throw new Error(`Failed to fetch weather: ${error.message}`);
    }
}
```

**Error Handling with Result Types:**
```javascript
export async function checkWeather(location, unit) {
  try {
    const weather = await getWeather(apiKey, params);
    return { ok: JSON.stringify(weather.toJSON()) };
  } catch (error) {
    return { err: error.message };
  }
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
├── app.js               # Main plugin implementation
├── wit/
│   └── world.wit        # Component interface definition
├── package.json         # Node.js dependencies and metadata
├── noorle.yaml          # Plugin permissions and configuration
├── .env.example         # Environment variable template
├── build.sh             # Build script (used by noorle CLI)
├── node_modules/        # Dependencies (created after npm install)
└── dist/                # Build output (created after build)
    └── plugin.wasm      # Compiled WASM component
```

## Key Dependencies

```json
{
  "dependencies": {
    "@bytecodealliance/componentize-js": "0.19.1",  // JavaScript to WASM compiler
    "@bytecodealliance/jco": "1.15.0"               // JavaScript Component Tools
  }
}
```

## API Reference

### `check-weather(location: string, unit: string) -> result<string, string>`

Fetches current weather information for a specified location.

**Parameters:**
- `location`: City name or "City,CountryCode" format (e.g., "Austin", "London,UK")
- `unit`: Temperature unit - "metric" (Celsius) or "imperial" (Fahrenheit)

**Returns:**
Success: JSON string containing weather data:
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

1. **JavaScript in WASM**: How to use modern JavaScript in WASM components
2. **Fetch API Patterns**: Making HTTP requests from sandboxed environments
3. **Environment Configuration**: Secure handling of API keys and configuration
4. **Error Handling**: Using Result types in JavaScript for robust error management
5. **Component Development**: Building reusable WASM components with JavaScript

This example serves as a foundation for building any plugin that needs external API integration, from weather services to database connectors to AI model APIs.