# Amadeus Flight Plugin (Go) - Noorle Example

A production-ready WebAssembly plugin for searching flight offers using the Amadeus Travel API, demonstrating complex data types, OAuth2 authentication, and real-world API integration with the Noorle platform.

## Why This Example Matters

This flight search plugin showcases advanced patterns for building production-ready Noorle plugins:

- **Complex Data Types**: Demonstrates handling of structured records with multiple optional fields
- **OAuth2 Authentication**: Shows secure token management with automatic refresh
- **Real API Integration**: Production-ready integration with Amadeus Travel APIs
- **WASI HTTP POST**: Proper implementation of POST requests with body in WASI
- **Environment Configuration**: Fully configurable via environment variables
- **Error Handling**: Robust patterns for network failures and API errors

## Features

- **Comprehensive Flight Search**: Search for one-way and round-trip flights
- **Flexible Traveler Configuration**: Support for adults, children, and infants
- **Travel Class Selection**: Economy, Premium Economy, Business, or First class
- **Airline Filtering**: Include or exclude specific airlines
- **Advanced Options**: Non-stop flights, currency selection, price limits
- **OAuth2 Authentication**: Automatic token refresh with proper POST body handling

## Getting Started

### Obtain Free API Credentials

Developers can register for **free self-service API access** at [https://developers.amadeus.com/](https://developers.amadeus.com/):

1. Sign up for a free account
2. Create a new app in the dashboard
3. Get your API Key and API Secret
4. Start with the test environment (free, with rate limits)
5. Upgrade to production when ready

The free tier includes access to the test environment with sample data, perfect for development and testing.

## Environment Configuration

All configuration is required via environment variables - no hardcoded values:

```bash
# Required - Amadeus API hostname (without https://)
# Use test.api.amadeus.com for testing (free tier)
# Use api.amadeus.com for production
AMADEUS_HOST=test.api.amadeus.com

# Required - Your Amadeus API credentials
# Get them free from https://developers.amadeus.com
AMADEUS_API_KEY=your_api_key_here
AMADEUS_API_SECRET=your_api_secret_here
```

## API Reference

### `search-flights(params: flight-search-params) -> string`

Searches for flight offers using the Amadeus API with comprehensive filtering options.

**Required Parameters:**
- `origin-location-code`: Origin airport/city IATA code (e.g., "JFK")
- `destination-location-code`: Destination IATA code (e.g., "LAX")
- `departure-date`: Departure date in YYYY-MM-DD format
- `adults`: Number of adult travelers (age 12+)

**Optional Parameters:**
- `return-date`: Return date for round-trip flights
- `children`: Number of child travelers (age 2-11)
- `infants`: Number of infant travelers (under 2)
- `travel-class`: Preferred class (economy, premium-economy, business, first)
- `included-airline-codes`: Comma-separated airline codes to include
- `excluded-airline-codes`: Comma-separated airline codes to exclude
- `non-stop`: Only show direct flights (true/false)
- `currency-code`: Preferred currency (default: USD)
- `max-price`: Maximum price per traveler
- `max-results`: Maximum number of offers (1-250, default: 10)

**Returns:** JSON string with flight offers or error message

## Building the Plugin

```bash
# Build the WASM component
./build.sh

# Output will be in dist/plugin.wasm (approximately 368K)
```

## Testing with wasmtime

The plugin uses WAVE (WebAssembly Value Encoding) syntax for complex types:

```bash
# Basic one-way flight search
wasmtime run --wasi http \
  --env AMADEUS_HOST=test.api.amadeus.com \
  --env AMADEUS_API_KEY=your_api_key \
  --env AMADEUS_API_SECRET=your_api_secret \
  --invoke 'search-flights({origin-location-code:"JFK",destination-location-code:"LAX",departure-date:"2025-12-20",adults:1})' \
  dist/plugin.wasm

# Round-trip with optional parameters
wasmtime run --wasi http \
  --env AMADEUS_HOST=test.api.amadeus.com \
  --env AMADEUS_API_KEY=your_api_key \
  --env AMADEUS_API_SECRET=your_api_secret \
  --invoke 'search-flights({origin-location-code:"NYC",destination-location-code:"LON",departure-date:"2025-12-20",return-date:"2025-12-27",adults:2,children:1,travel-class:"business",non-stop:true,max-results:5})' \
  dist/plugin.wasm
```

## Implementation Highlights

### OAuth2 with WASI HTTP POST

The plugin properly implements OAuth2 token refresh using WASI HTTP POST with body:

```go
func refreshToken() error {
    // OAuth2 token request with proper POST body
    formData := fmt.Sprintf("grant_type=client_credentials&client_id=%s&client_secret=%s",
        config.APIKey, config.APISecret)

    headers := map[string]string{
        "Content-Type": "application/x-www-form-urlencoded",
    }

    body := []byte(formData)
    respBody, err := makeHTTPRequest("POST", path, headers, body)
    // ...
}
```

### WASI HTTP POST Body Implementation

Proper resource management for POST requests in WASI:

```go
// Write body for POST requests
if method == "POST" && body != nil && len(body) > 0 {
    bodyResult := request.Body()
    outgoingBody := bodyResult.OK()

    streamResult := outgoingBody.Write()
    bodyStream := streamResult.OK()

    // Write the body data
    bodyStream.BlockingWriteAndFlush(cm.ToList(body))

    // Proper resource cleanup
    bodyStream.ResourceDrop()
    types.OutgoingBodyFinish(*outgoingBody, cm.None[types.Trailers]())
}
```

### Complex Type Handling with cm v0.3.0

Using the correct Option API for optional parameters:

```go
// Handle optional parameters with cm v0.3.0 API
if returnDate := params.ReturnDate.Some(); returnDate != nil {
    queryParams += fmt.Sprintf("&returnDate=%s", *returnDate)
}
if nonStop := params.NonStop.Some(); nonStop != nil {
    queryParams += fmt.Sprintf("&nonStop=%t", *nonStop)
}
```

## Project Structure

```
amadeus-flight/
├── main.go              # Main implementation with OAuth2 and API calls
├── wit/
│   └── world.wit        # WIT interface with complex record types
├── go.mod               # Go module (uses cm v0.3.0)
├── build.sh             # Build script for TinyGo WASM compilation
├── .env.example         # Environment variable template
├── noorle.yaml          # Plugin permissions configuration
├── gen/                 # Generated WIT bindings (created during build)
└── dist/                # Build output
    └── plugin.wasm      # Compiled WASM component
```

## WIT Interface Design

The plugin demonstrates complex record types with optional fields:

```wit
world amadeus-flight-component {
    record flight-search-params {
        origin-location-code: string,
        destination-location-code: string,
        departure-date: string,
        adults: u32,
        return-date: option<string>,
        children: option<u32>,
        infants: option<u32>,
        travel-class: option<string>,
        included-airline-codes: option<string>,
        excluded-airline-codes: option<string>,
        non-stop: option<bool>,
        currency-code: option<string>,
        max-price: option<u32>,
        max-results: option<u32>,
    }

    export search-flights: func(params: flight-search-params) -> string;
}
```

## Troubleshooting

### OAuth2 Token Refresh
The plugin automatically refreshes OAuth2 tokens before they expire. If you see authentication errors, check your API credentials.

### Date Validation
Ensure departure dates are in the future. The API returns error 425 "INVALID DATE" for past dates.

### Environment Variables
All three environment variables are required:
- `AMADEUS_HOST` (e.g., `test.api.amadeus.com`)
- `AMADEUS_API_KEY`
- `AMADEUS_API_SECRET`

## Key Learnings

1. **WASI HTTP POST**: Proper implementation of POST requests with body in WASI requires careful resource management
2. **OAuth2 in WASM**: Token management works seamlessly with proper POST implementation
3. **Complex Types**: WAVE syntax enables passing complex records to WASM functions
4. **Environment Config**: Full configurability without hardcoded values
5. **Resource Cleanup**: Proper order of operations for WASI resource dropping

## API Response Example

```json
{
  "meta": {
    "count": 10,
    "links": {
      "self": "https://test.api.amadeus.com/v2/shopping/flight-offers?..."
    }
  },
  "data": [
    {
      "type": "flight-offer",
      "id": "1",
      "price": {
        "currency": "EUR",
        "total": "166.79",
        "base": "131.00"
      },
      "itineraries": [
        {
          "duration": "PT5H22M",
          "segments": [
            {
              "departure": {
                "iataCode": "JFK",
                "at": "2025-12-20T21:55:00"
              },
              "arrival": {
                "iataCode": "LAX",
                "at": "2025-12-21T01:17:00"
              },
              "carrierCode": "B6",
              "number": "2724"
            }
          ]
        }
      ]
    }
  ]
}
```

## Notes

- **Free API Access**: Register at [https://developers.amadeus.com/](https://developers.amadeus.com/) for free test environment access
- **Test vs Production**: Use test.api.amadeus.com for development (free tier, lower rate limits)
- **Token Expiry**: OAuth2 tokens expire after 30 minutes and are automatically refreshed
- **WASI Limitations**: This implementation works around WASI HTTP limitations through proper resource management
- **Performance**: Compiled WASM size is optimized to ~368K with TinyGo

This example demonstrates production-ready patterns for complex API integration within the WebAssembly Component Model ecosystem.