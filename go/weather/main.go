package main

import (
	"encoding/json"
	"fmt"
	"net/url"
	"strings"

	weathercomponent "github.com/my_org/weather/gen/example/weather/weather-component"
	"github.com/my_org/weather/gen/wasi/cli/environment"
	outgoinghandler "github.com/my_org/weather/gen/wasi/http/outgoing-handler"
	"github.com/my_org/weather/gen/wasi/http/types"
	"github.com/my_org/weather/gen/wasi/io/poll"
	"go.bytecodealliance.org/cm"
)

const OPENWEATHER_HOST = "api.openweathermap.org"
const OPENWEATHER_PATH = "/data/2.5/weather"

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

type OpenWeatherResponse struct {
	Name string `json:"name"`
	Main struct {
		Temp      float64 `json:"temp"`
		FeelsLike float64 `json:"feels_like"`
		Humidity  int     `json:"humidity"`
	} `json:"main"`
	Wind struct {
		Speed float64 `json:"speed"`
		Deg   int     `json:"deg"`
	} `json:"wind"`
	Weather []struct {
		Description string `json:"description"`
	} `json:"weather"`
}

func makeHTTPRequest(pathWithQuery string) ([]byte, error) {
	// Create headers
	headers := types.NewFields()
	userAgent := cm.ToList([]uint8("Mozilla/5.0 (compatible; noorle/1.0"))
	headers.Append("User-Agent", types.FieldValue(userAgent))


	// Create the request
	request := types.NewOutgoingRequest(headers)


	// Set request properties
	request.SetMethod(types.MethodGet())
	request.SetScheme(cm.Some(types.SchemeHTTPS()))
	request.SetAuthority(cm.Some(OPENWEATHER_HOST))
	request.SetPathWithQuery(cm.Some(pathWithQuery))

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
	if status < 200 || status >= 300 {
		return nil, fmt.Errorf("HTTP error: status code %d", status)
	}

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
	stream := streamResult.OK()
	defer stream.ResourceDrop()

	// Read the body
	var body []byte
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

	return body, nil
}

func getWeather(apiKey string, location string, unit string) (*WeatherResponse, error) {
	unitQuery := unit
	if unit != "metric" && unit != "imperial" {
		unitQuery = "metric"
	}

	// URL-encode the location parameter
	encodedLocation := url.QueryEscape(location)

	// Build the path with query
	pathWithQuery := fmt.Sprintf(
		"%s?q=%s&appid=%s&units=%s",
		OPENWEATHER_PATH, encodedLocation, apiKey, unitQuery,
	)

	// Make the HTTP request
	body, err := makeHTTPRequest(pathWithQuery)
	if err != nil {
		return nil, err
	}

	// Parse JSON
	var weatherData OpenWeatherResponse
	err = json.Unmarshal(body, &weatherData)
	if err != nil {
		return nil, fmt.Errorf("failed to parse JSON response: %v", err)
	}

	// Build response
	weatherResponse := &WeatherResponse{
		Location:             weatherData.Name,
		Temperature:          weatherData.Main.Temp,
		FeelsLikeTemperature: weatherData.Main.FeelsLike,
		Unit:                 unitQuery,
		WeatherConditions:    make([]string, 0),
	}

	// Add optional fields
	if weatherData.Wind.Speed > 0 {
		windSpeed := weatherData.Wind.Speed
		weatherResponse.WindSpeed = &windSpeed
	}
	if weatherData.Wind.Deg > 0 {
		windDeg := weatherData.Wind.Deg
		weatherResponse.WindDegrees = &windDeg
	}
	if weatherData.Main.Humidity > 0 {
		humidity := weatherData.Main.Humidity
		weatherResponse.Humidity = &humidity
	}

	// Add weather conditions
	for _, w := range weatherData.Weather {
		if w.Description != "" {
			weatherResponse.WeatherConditions = append(weatherResponse.WeatherConditions, w.Description)
		}
	}

	return weatherResponse, nil
}

func init() {
	weathercomponent.Exports.CheckWeather = func(location string, unit string) string {
		// Get API key from environment using WASI
		var apiKey string
		envVars := environment.GetEnvironment().Slice()
		for _, env := range envVars {
			if env[0] == "OPENWEATHER_API_KEY" {
				apiKey = env[1]
				break
			}
		}

		if apiKey == "" {
			errorResp := map[string]string{
				"error": "OPENWEATHER_API_KEY environment variable not set",
			}
			result, _ := json.Marshal(errorResp)
			return string(result)
		}

		// Normalize unit parameter
		unit = strings.ToLower(unit)
		if unit != "metric" && unit != "imperial" {
			unit = "metric" // Default to metric if invalid unit provided
		}

		// Call the weather API
		weather, err := getWeather(apiKey, location, unit)
		if err != nil {
			errorResp := map[string]string{
				"error": fmt.Sprintf("Failed to fetch weather: %v", err),
			}
			result, _ := json.Marshal(errorResp)
			return string(result)
		}

		// Return result as JSON
		result, err := json.Marshal(weather)
		if err != nil {
			errorResp := map[string]string{
				"error": fmt.Sprintf("Failed to serialize response: %v", err),
			}
			result, _ = json.Marshal(errorResp)
			return string(result)
		}

		return string(result)
	}
}

// Required for WASM
func main() {}