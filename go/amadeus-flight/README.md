# Amadeus Flight Plugin (Go) - Historical Noorle Example

> [!NOTE]
> [Amadeus retired its Self-Service developer portal](https://developers.amadeus.com/api-catalog). This example is preserved as a code reference, not as a runnable flight-search integration. It has not been adapted or verified for Amadeus Enterprise APIs.

The TinyGo guest demonstrates structured WIT records with optional fields, OAuth 2.0 client credentials, and sending a request body with WASI HTTP. Start with [`main.go`](main.go) for the guest implementation and [`wit/world.wit`](wit/world.wit) for the exported interface.

## Historical API contract

### `search-flights(params: flight-search-params) -> string`

The export accepted a structured search request and returned flight offers from Amadeus Self-Service.

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

**Returns:** A string containing JSON flight offers or an error message.

## Build the component

```bash
bash ./build.sh
```

This produces `dist/plugin.wasm`. A successful build does not verify a live API call.

## Implementation Highlights

### OAuth2 with WASI HTTP POST

The source shows how the guest requested an OAuth 2.0 access token using a WASI HTTP POST:

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

The guest wrote and flushed the request body, then released the stream before finishing the body:

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

## Historical response example

This sample illustrates the old Self-Service response shape. It is not live flight data.

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
