import json
from enum import Enum
from typing import Optional, List
from dataclasses import dataclass
from urllib.parse import quote
import wit_world

# Import WASI HTTP bindings
from wit_world.imports import types as http_types
from wit_world.imports import outgoing_handler
from wit_world.imports import environment
from wit_world.imports import poll as poll_module
from wit_world.types import Ok, Err

OPENWEATHER_ENDPOINT = "api.openweathermap.org"
TIMEOUT_SECS = 10


class Unit(str, Enum):
    METRIC = "metric"
    IMPERIAL = "imperial"


@dataclass
class WeatherParams:
    location: str
    unit: Unit


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

    def to_dict(self):
        result = {
            "location": self.location,
            "temperature": self.temperature,
            "feels_like_temperature": self.feels_like_temperature,
            "unit": self.unit.lower() if isinstance(self.unit, Unit) else self.unit,
            "weather_conditions": self.weather_conditions
        }
        if self.wind_speed is not None:
            result["wind_speed"] = self.wind_speed
        if self.wind_degrees is not None:
            result["wind_degrees"] = self.wind_degrees
        if self.humidity is not None:
            result["humidity"] = self.humidity
        return result


def make_http_request(url: str, headers_dict: dict) -> bytes:
    """Make an HTTP GET request using WASI HTTP"""
    # Based on the official componentize-py HTTP example

    # Create headers
    headers = http_types.Fields()
    for key, value in headers_dict.items():
        headers.append(key, value.encode())

    # Create the request
    request = http_types.OutgoingRequest(headers)
    request.set_method(http_types.Method_Get())
    request.set_scheme(http_types.Scheme_Https())
    request.set_authority(OPENWEATHER_ENDPOINT)

    # Extract path and query from URL
    path_with_query = url.replace(f"https://{OPENWEATHER_ENDPOINT}", "")
    request.set_path_with_query(path_with_query)

    # Send the request
    response = outgoing_handler.handle(request, None)

    # Subscribe to the response
    response_pollable = response.subscribe()

    # Block until the response is ready
    poll_module.poll([response_pollable])

    # Get the response
    result = response.get()

    # The example shows simpler error handling
    if result is None:
        raise Exception("No response received")

    # Handle the outer Result[Result[IncomingResponse, ErrorCode], None]
    # First check if it's an Ok or Err
    if isinstance(result, Err):
        raise Exception(f"Failed to get response: {result.value}")

    # Get the inner Result[IncomingResponse, ErrorCode]
    inner_result = result.value if isinstance(result, Ok) else result

    # Check if inner result is an error
    if isinstance(inner_result, Err):
        raise Exception(f"Request failed with error code: {inner_result.value}")

    # Get the actual response
    incoming_response = inner_result.value if isinstance(inner_result, Ok) else inner_result
    status = incoming_response.status()

    if not (200 <= status < 300):
        raise Exception(f"HTTP error: status code {status}")

    # Consume the body
    incoming_body = incoming_response.consume()
    body_stream = incoming_body.stream()

    # Read the body using blocking reads
    chunks = []
    try:
        while True:
            # Use blocking_read to ensure we get data
            body_chunk = body_stream.blocking_read(8192)
            if len(body_chunk) == 0:
                break
            chunks.append(body_chunk)
    except Exception as e:
        # If we get a stream error, check if we have data
        if chunks:
            pass  # We have some data, continue
        else:
            raise Exception(f"Failed to read response body: {e}")

    return b"".join(chunks)


def get_weather(api_key: str, params: WeatherParams) -> WeatherResponse:
    unit_query = params.unit.value

    # URL-encode the location parameter
    encoded_location = quote(params.location)

    request_url = f"https://{OPENWEATHER_ENDPOINT}/data/2.5/weather?q={encoded_location}&appid={api_key}&units={unit_query}"

    # Make HTTP request using WASI HTTP
    try:
        headers = {"User-Agent": "Mozilla/5.0 (compatible; noorle/1.0)"}
        body = make_http_request(request_url, headers)
        weather_data = json.loads(body.decode('utf-8'))

        # Extract weather conditions
        weather_conditions = []
        if "weather" in weather_data:
            weather_conditions = [
                w.get("description", "")
                for w in weather_data["weather"]
                if "description" in w
            ]

        # Build response
        weather_response = WeatherResponse(
            location=weather_data.get("name", ""),
            temperature=weather_data["main"]["temp"],
            feels_like_temperature=weather_data["main"]["feels_like"],
            wind_speed=weather_data.get("wind", {}).get("speed"),
            wind_degrees=weather_data.get("wind", {}).get("deg"),
            humidity=weather_data.get("main", {}).get("humidity"),
            unit=params.unit.value,
            weather_conditions=weather_conditions
        )

        return weather_response

    except KeyError as e:
        raise Exception(f"Error parsing weather data: missing field {e}")
    except Exception as e:
        raise Exception(f"Failed to fetch weather: {e}")


class WitWorld(wit_world.WitWorld):
    def check_weather(self, location: str, unit: str) -> str:
        # Get API key from environment variables
        env_vars = environment.get_environment()
        api_key = None

        for var in env_vars:
            if var[0] == "OPENWEATHER_API_KEY":
                api_key = var[1]
                break

        if not api_key:
            return json.dumps({
                "error": "OPENWEATHER_API_KEY environment variable not set"
            })

        # Parse unit parameter
        unit_lower = unit.lower()
        if unit_lower == "imperial":
            unit_enum = Unit.IMPERIAL
        else:
            unit_enum = Unit.METRIC  # Default to metric if invalid unit provided

        params = WeatherParams(
            location=location,
            unit=unit_enum
        )

        # Call the weather API and return result as JSON
        try:
            weather = get_weather(api_key, params)
            return json.dumps(weather.to_dict())
        except Exception as e:
            return json.dumps({
                "error": f"Failed to fetch weather: {e}"
            })