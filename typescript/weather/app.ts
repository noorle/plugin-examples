import { getEnvironment } from "wasi:cli/environment@0.2.7";

const OPENWEATHER_ENDPOINT = "https://api.openweathermap.org/data/2.5/weather";
const TIMEOUT_SECS = 10000; // 10 seconds in milliseconds

// Unit enum
enum Unit {
  METRIC = "metric",
  IMPERIAL = "imperial"
}

interface WeatherParamsData {
  location: string;
  unit: Unit;
}

class WeatherParams {
  location: string;
  unit: Unit;

  constructor(location: string, unit: Unit) {
    this.location = location;
    this.unit = unit;
  }
}

interface WeatherResponseData {
  location: string;
  temperature: number;
  feels_like_temperature: number;
  wind_speed: number | null;
  wind_degrees: number | null;
  humidity: number | null;
  unit: Unit;
  weather_conditions: string[];
}

class WeatherResponse {
  location: string;
  temperature: number;
  feels_like_temperature: number;
  wind_speed: number | null;
  wind_degrees: number | null;
  humidity: number | null;
  unit: Unit;
  weather_conditions: string[];

  constructor(data: WeatherResponseData) {
    this.location = data.location;
    this.temperature = data.temperature;
    this.feels_like_temperature = data.feels_like_temperature;
    this.wind_speed = data.wind_speed;
    this.wind_degrees = data.wind_degrees;
    this.humidity = data.humidity;
    this.unit = data.unit;
    this.weather_conditions = data.weather_conditions;
  }

  toJSON(): Record<string, any> {
    const result: Record<string, any> = {
      location: this.location,
      temperature: this.temperature,
      feels_like_temperature: this.feels_like_temperature,
      unit: this.unit,
      weather_conditions: this.weather_conditions
    };

    if (this.wind_speed !== null && this.wind_speed !== undefined) {
      result.wind_speed = this.wind_speed;
    }
    if (this.wind_degrees !== null && this.wind_degrees !== undefined) {
      result.wind_degrees = this.wind_degrees;
    }
    if (this.humidity !== null && this.humidity !== undefined) {
      result.humidity = this.humidity;
    }

    return result;
  }
}

async function getWeather(apiKey: string, params: WeatherParams): Promise<WeatherResponse> {
  const unitQuery = params.unit;

  // URL-encode the location parameter
  const encodedLocation = encodeURIComponent(params.location);

  const requestUrl = `${OPENWEATHER_ENDPOINT}?q=${encodedLocation}&appid=${apiKey}&units=${unitQuery}`;

  try {
    // Use fetch API which is available in ComponentizeJS environment
    const response = await fetch(requestUrl, {
      method: 'GET',
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; noorle/1.0)'
      },
      // Note: ComponentizeJS doesn't support AbortController timeout yet
      // so we rely on the underlying WASI implementation for timeouts
    });

    if (!response.ok) {
      throw new Error(`HTTP error: status code ${response.status}`);
    }

    const weatherData = await response.json();

    // Extract weather conditions
    const weatherConditions: string[] = [];
    if (weatherData.weather && Array.isArray(weatherData.weather)) {
      for (const w of weatherData.weather) {
        if (w.description) {
          weatherConditions.push(w.description);
        }
      }
    }

    // Build response
    const weatherResponse = new WeatherResponse({
      location: weatherData.name || "",
      temperature: weatherData.main?.temp,
      feels_like_temperature: weatherData.main?.feels_like,
      wind_speed: weatherData.wind?.speed || null,
      wind_degrees: weatherData.wind?.deg || null,
      humidity: weatherData.main?.humidity || null,
      unit: params.unit,
      weather_conditions: weatherConditions
    });

    if (weatherResponse.temperature === undefined || weatherResponse.feels_like_temperature === undefined) {
      throw new Error("Error parsing temperature data");
    }

    return weatherResponse;

  } catch (error) {
    throw new Error(`Failed to fetch weather: ${(error as Error).message}`);
  }
}

// Export the main function that will be called by the WASM component
export async function checkWeather(location: string, unit: string): Promise<string> {
  try {
    // Get API key from environment variables
    const envVars = getEnvironment();
    let apiKey = "";

    for (const [key, value] of envVars) {
      if (key === "OPENWEATHER_API_KEY") {
        apiKey = value;
        break;
      }
    }

    if (!apiKey) {
      return JSON.stringify({
        error: "OPENWEATHER_API_KEY environment variable not set"
      });
    }

    // Parse unit parameter
    const unitLower = unit.toLowerCase();
    let unitEnum: Unit;
    if (unitLower === "imperial") {
      unitEnum = Unit.IMPERIAL;
    } else {
      unitEnum = Unit.METRIC; // Default to metric if invalid unit provided
    }

    const params = new WeatherParams(location, unitEnum);

    // Call the weather API and return result as JSON
    const weather = await getWeather(apiKey, params);
    return JSON.stringify(weather.toJSON());

  } catch (error) {
    return JSON.stringify({
      error: (error as Error).message
    });
  }
}