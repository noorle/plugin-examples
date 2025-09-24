# Weather Plugin (TypeScript) - Noorle Example

A reference implementation demonstrating HTTP API integration in Noorle plugins using TypeScript, ComponentizeJS, and the WebAssembly Component Model with WASI 0.2.

## Why This Example Matters

This weather plugin showcases real-world patterns for building production-ready Noorle plugins with TypeScript:

- **Type-Safe Development**: Full TypeScript support with strict typing and compile-time checks
- **HTTP Client Integration**: Shows how to make external API calls from WASM components using TypeScript
- **Environment Variable Handling**: Secure configuration management in sandboxed environments
- **Error Handling**: Robust patterns for network failures and API errors with TypeScript types
- **JSON Processing**: Type-safe JSON serialization and deserialization
- **Component Interface Design**: Clean, documented APIs using WIT (WebAssembly Interface Types)

## Architecture & Technology Choices

**WebAssembly Component Model with WASI 0.2** provides secure, portable sandboxing with standardized system interfaces, making plugins safe to run anywhere while maintaining access to essential system capabilities.

**TypeScript → JavaScript → WASM Pipeline:**
```
app.ts → app.js → plugin.wasm
   ↓        ↓         ↓
TypeScript → JavaScript → WebAssembly
Compiler   ComponentizeJS   Component
```

- **Stage 1**: TypeScript compilation with strict type checking
- **Stage 2**: ComponentizeJS compiles JavaScript to WASM components using StarlingMonkey runtime
- Built on SpiderMonkey (Firefox's JavaScript engine) optimized for WASM
- Native `fetch()` API support for familiar HTTP client patterns
- Full TypeScript development experience with modern JavaScript output

**Why TypeScript for WASM:**
- Type safety catches errors at compile time
- IntelliSense and autocomplete in IDEs
- Familiar development experience with modern TypeScript
- Native JSON handling without external libraries
- Seamless integration with existing TypeScript codebases

## HTTP Client Implementation Deep Dive

### Type-Safe Fetch Pattern

```typescript
async function getWeather(apiKey: string, params: WeatherParams): Promise<WeatherResponse> {
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
        return new WeatherResponse(processWeatherData(weatherData));
    } catch (error) {
        throw new Error(`Failed to fetch weather: ${(error as Error).message}`);
    }
}
```

**Error Handling with TypeScript:**
```typescript
export async function checkWeather(location: string, unit: string): Promise<string> {
    try {
        const weather = await getWeather(apiKey, params);
        return JSON.stringify(weather.toJSON());
    } catch (error) {
        return JSON.stringify({ error: (error as Error).message });
    }
}
```

## Component Model Benefits

- **Security**: Capability-based permissions limit network access to specified hosts only
- **Portability**: Runs on any WASI 0.2 runtime (wasmtime, wasmer, browser, etc.)
- **Composition**: Plugins can import/export interfaces to work with other components
- **Language Agnostic**: WIT interfaces allow seamless interop between different language implementations
- **Type Safety**: TypeScript provides compile-time guarantees

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
├── app.ts               # Main plugin implementation (TypeScript)
├── wit/
│   └── world.wit        # Component interface definition
├── package.json         # Node.js dependencies and metadata
├── tsconfig.json        # TypeScript compiler configuration
├── noorle.yaml          # Plugin permissions and configuration
├── .env.example         # Environment variable template
├── build.sh             # Build script (used by noorle CLI)
├── node_modules/        # Dependencies (created after npm install)
└── dist/                # Build output (created after build)
    ├── app.js           # Compiled JavaScript (intermediate)
    └── plugin.wasm      # Compiled WASM component
```

## Key Dependencies

```json
{
  "dependencies": {
    "@bytecodealliance/componentize-js": "0.19.1",  // JavaScript to WASM compiler
    "@bytecodealliance/jco": "1.15.0"               // JavaScript Component Tools
  },
  "devDependencies": {
    "typescript": "^5.0.0",                         // TypeScript compiler
    "@types/node": "^18.0.0"                        // Node.js type definitions
  }
}
```

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

## TypeScript Features Demonstrated

- **Enums** for type-safe constants:
  ```typescript
  enum Unit {
    METRIC = "metric",
    IMPERIAL = "imperial"
  }
  ```

- **Interfaces** for data contracts:
  ```typescript
  interface WeatherResponseData {
    location: string;
    temperature: number;
    // ...
  }
  ```

- **Classes** for encapsulation:
  ```typescript
  class WeatherResponse {
    constructor(data: WeatherResponseData) {
      // ...
    }
  }
  ```

- **Type Guards** and proper error handling:
  ```typescript
  } catch (error) {
    return JSON.stringify({ error: (error as Error).message });
  }
  ```

## Build Process

The build script implements a two-stage compilation:

1. **TypeScript Compilation**:
   - Type checking with `tsc --noEmit`
   - Compilation to ES2022 JavaScript
   - Outputs to `dist/app.js`

2. **WASM Generation**:
   - ComponentizeJS processes the JavaScript
   - Generates WASI 2.0 compatible component
   - Creates final `dist/plugin.wasm`

## Learning Outcomes

By studying this example, developers learn:

1. **TypeScript in WASM**: How to use TypeScript for WASM component development
2. **Type-Safe APIs**: Building robust, type-safe plugin interfaces
3. **Fetch API Patterns**: Making HTTP requests from sandboxed environments with TypeScript
4. **Environment Configuration**: Secure handling of API keys and configuration
5. **Build Pipelines**: Multi-stage compilation from TypeScript to WASM

This example serves as a foundation for building any plugin that needs external API integration with the benefits of TypeScript's type safety and modern development experience.