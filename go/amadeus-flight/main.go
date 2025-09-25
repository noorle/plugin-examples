package main

import (
	"encoding/json"
	"fmt"
	"strings"
	"time"

	amadeusflightcomponent "github.com/my_org/amadeus-flight/gen/example/amadeus-flight/amadeus-flight-component"
	"github.com/my_org/amadeus-flight/gen/wasi/cli/environment"
	outgoinghandler "github.com/my_org/amadeus-flight/gen/wasi/http/outgoing-handler"
	"github.com/my_org/amadeus-flight/gen/wasi/http/types"
	"github.com/my_org/amadeus-flight/gen/wasi/io/poll"
	"go.bytecodealliance.org/cm"
)

var AMADEUS_HOST string

type Config struct {
	APIKey     string
	APISecret  string
	Token      string
	Expiration int64
}

type TokenResponse struct {
	AccessToken string `json:"access_token"`
	TokenType   string `json:"token_type"`
	ExpiresIn   int64  `json:"expires_in"`
}

var config = &Config{}

func makeHTTPRequest(method string, pathWithQuery string, headers map[string]string, body []byte) ([]byte, error) {
	// Create headers
	headersFields := types.NewFields()
	userAgent := cm.ToList([]uint8("Mozilla/5.0 (compatible; noorle/1.0)"))
	headersFields.Append(types.FieldKey("User-Agent"), types.FieldValue(userAgent))

	for key, value := range headers {
		valueBytes := cm.ToList([]uint8(value))
		headersFields.Append(types.FieldKey(key), types.FieldValue(valueBytes))
	}

	// Create the request
	request := types.NewOutgoingRequest(headersFields)

	// Set request properties
	var httpMethod types.Method
	switch strings.ToUpper(method) {
	case "GET":
		httpMethod = types.MethodGet()
	case "POST":
		httpMethod = types.MethodPost()
	default:
		httpMethod = types.MethodGet()
	}

	request.SetMethod(httpMethod)
	request.SetScheme(cm.Some(types.SchemeHTTPS()))
	request.SetAuthority(cm.Some(AMADEUS_HOST))
	request.SetPathWithQuery(cm.Some(pathWithQuery))

	// Write body for POST requests
	if method == "POST" && body != nil && len(body) > 0 {
		bodyResult := request.Body()
		if bodyResult.IsErr() {
			return nil, fmt.Errorf("failed to get request body: %v", bodyResult.Err())
		}
		outgoingBody := bodyResult.OK()

		streamResult := outgoingBody.Write()
		if streamResult.IsErr() {
			outgoingBody.ResourceDrop()
			return nil, fmt.Errorf("failed to get body stream: %v", streamResult.Err())
		}
		bodyStream := streamResult.OK()

		// Write the body data
		writeResult := bodyStream.BlockingWriteAndFlush(cm.ToList(body))
		if writeResult.IsErr() {
			bodyStream.ResourceDrop()
			outgoingBody.ResourceDrop()
			return nil, fmt.Errorf("failed to write body: %v", writeResult.Err())
		}

		// Drop the stream first
		bodyStream.ResourceDrop()

		// Finish the body (this consumes the outgoing body)
		finishResult := types.OutgoingBodyFinish(*outgoingBody, cm.None[types.Trailers]())
		if finishResult.IsErr() {
			// Don't drop outgoingBody here since Finish consumes it
			return nil, fmt.Errorf("failed to finish body: %v", finishResult.Err())
		}
		// Don't drop outgoingBody here either since Finish consumed it
	}

	// Send the request
	futureResponseResult := outgoinghandler.Handle(request, cm.None[types.RequestOptions]())
	if futureResponseResult.IsErr() {
		return nil, fmt.Errorf("failed to handle request: %v", futureResponseResult.Err())
	}
	futureResponse := futureResponseResult.OK()
	defer futureResponse.ResourceDrop()

	// Subscribe to the response
	pollable := futureResponse.Subscribe()
	defer pollable.ResourceDrop()

	// Wait for the response
	poll.Poll(cm.ToList([]types.Pollable{pollable}))

	// Get the response
	optionResult := futureResponse.Get()
	result := optionResult.Some()
	if result == nil {
		return nil, fmt.Errorf("request timed out")
	}

	// Handle the response
	if result.IsErr() {
		return nil, fmt.Errorf("request failed: %v", result.Err())
	}

	responseResult := result.OK()
	if responseResult.IsErr() {
		return nil, fmt.Errorf("HTTP error: %v", responseResult.Err())
	}

	response := responseResult.OK()
	defer response.ResourceDrop()

	// Check status
	status := response.Status()

	// Consume the body
	bodyResult := response.Consume()
	if bodyResult.IsErr() {
		return nil, fmt.Errorf("failed to consume body: %v", bodyResult.Err())
	}
	bodyResource := bodyResult.OK()
	defer bodyResource.ResourceDrop()

	streamResult := bodyResource.Stream()
	if streamResult.IsErr() {
		return nil, fmt.Errorf("failed to get stream: %v", streamResult.Err())
	}
	streamRes := streamResult.OK()
	defer streamRes.ResourceDrop()

	// Read the body
	var respBody []byte
	for {
		readResult := streamRes.BlockingRead(65536)
		if readResult.IsErr() {
			err := readResult.Err()
			if err.Closed() {
				break
			}
			return nil, fmt.Errorf("failed to read response body: %v", err)
		}
		respBody = append(respBody, readResult.OK().Slice()...)
	}

	if status < 200 || status >= 300 {
		return nil, fmt.Errorf("HTTP error: status code %d, body: %s", status, string(respBody))
	}

	return respBody, nil
}

func getEnvVar(name string) string {
	envVars := environment.GetEnvironment().Slice()
	for _, env := range envVars {
		if env[0] == name {
			return env[1]
		}
	}
	return ""
}

func loadConfig() error {
	if config.APIKey != "" && config.APISecret != "" && AMADEUS_HOST != "" {
		return nil
	}

	// Load Amadeus host (just the hostname, no protocol)
	AMADEUS_HOST = getEnvVar("AMADEUS_HOST")
	if AMADEUS_HOST == "" {
		return fmt.Errorf("AMADEUS_HOST environment variable is required")
	}

	config.APIKey = getEnvVar("AMADEUS_API_KEY")
	config.APISecret = getEnvVar("AMADEUS_API_SECRET")

	if config.APIKey == "" || config.APISecret == "" {
		return fmt.Errorf("AMADEUS_API_KEY and AMADEUS_API_SECRET environment variables are required")
	}

	return nil
}

func refreshToken() error {
	// OAuth2 token request with proper POST body
	formData := fmt.Sprintf("grant_type=client_credentials&client_id=%s&client_secret=%s",
		config.APIKey, config.APISecret)

	headers := map[string]string{
		"Content-Type": "application/x-www-form-urlencoded",
	}

	path := "/v1/security/oauth2/token"
	body := []byte(formData)

	respBody, err := makeHTTPRequest("POST", path, headers, body)
	if err != nil {
		return fmt.Errorf("failed to refresh token: %v", err)
	}

	var tokenResp TokenResponse
	if err := json.Unmarshal(respBody, &tokenResp); err != nil {
		return fmt.Errorf("failed to parse token response: %v", err)
	}

	config.Token = tokenResp.AccessToken
	config.Expiration = time.Now().UTC().Unix() + tokenResp.ExpiresIn

	return nil
}

func searchFlights(params amadeusflightcomponent.FlightSearchParams) (string, error) {
	// Load configuration
	if err := loadConfig(); err != nil {
		return "", err
	}

	// Check if token needs refresh
	if config.Token == "" || time.Now().UTC().Unix() >= config.Expiration {
		if err := refreshToken(); err != nil {
			return "", err
		}
	}

	// Build query parameters
	queryParams := fmt.Sprintf("originLocationCode=%s&destinationLocationCode=%s&departureDate=%s&adults=%d",
		params.OriginLocationCode,
		params.DestinationLocationCode,
		params.DepartureDate,
		params.Adults)

	// Add optional parameters
	if returnDate := params.ReturnDate.Some(); returnDate != nil {
		queryParams += fmt.Sprintf("&returnDate=%s", *returnDate)
	}
	if children := params.Children.Some(); children != nil {
		queryParams += fmt.Sprintf("&children=%d", *children)
	}
	if infants := params.Infants.Some(); infants != nil {
		queryParams += fmt.Sprintf("&infants=%d", *infants)
	}
	if travelClass := params.TravelClass.Some(); travelClass != nil {
		queryParams += fmt.Sprintf("&travelClass=%s", *travelClass)
	}
	if includedCodes := params.IncludedAirlineCodes.Some(); includedCodes != nil {
		queryParams += fmt.Sprintf("&includedAirlineCodes=%s", *includedCodes)
	}
	if excludedCodes := params.ExcludedAirlineCodes.Some(); excludedCodes != nil {
		queryParams += fmt.Sprintf("&excludedAirlineCodes=%s", *excludedCodes)
	}
	if nonStop := params.NonStop.Some(); nonStop != nil {
		queryParams += fmt.Sprintf("&nonStop=%t", *nonStop)
	}
	if currencyCode := params.CurrencyCode.Some(); currencyCode != nil {
		queryParams += fmt.Sprintf("&currencyCode=%s", *currencyCode)
	}
	if maxPrice := params.MaxPrice.Some(); maxPrice != nil {
		queryParams += fmt.Sprintf("&max=%d", *maxPrice)
	}
	if maxResults := params.MaxResults.Some(); maxResults != nil {
		queryParams += fmt.Sprintf("&max=%d", *maxResults)
	} else {
		queryParams += "&max=10" // Default to 10 results
	}

	// Make API request
	path := fmt.Sprintf("/v2/shopping/flight-offers?%s", queryParams)
	headers := map[string]string{
		"Authorization": fmt.Sprintf("Bearer %s", config.Token),
		"Accept": "application/json",
	}

	respBody, err := makeHTTPRequest("GET", path, headers, nil)
	if err != nil {
		return "", fmt.Errorf("API request failed: %v", err)
	}

	return string(respBody), nil
}

func init() {
	amadeusflightcomponent.Exports.SearchFlights = func(params amadeusflightcomponent.FlightSearchParams) string {
		result, err := searchFlights(params)
		if err != nil {
			errorResp := map[string]string{
				"error": fmt.Sprintf("Failed to search flights: %v", err),
			}
			data, _ := json.Marshal(errorResp)
			return string(data)
		}
		return result
	}
}

// Required for WASM
func main() {}