#![allow(unsafe_op_in_unsafe_fn)]

mod types;

wit_bindgen::generate!({
    world: "weather-component",
    path: "./wit",
});

use anyhow::{Error, Result};
use std::time::Duration;
use types::{OpenWeatherResponse, WeatherParams};
use waki::Client;

const OPENWEATHER_ENDPOINT: &str = "https://api.openweathermap.org/data/2.5/weather";
const TIMEOUT_SECS: u64 = 10;

fn get_weather(api_key: &str, params: WeatherParams) -> Result<WeatherResponse, Error> {
    let unit_query = match params.unit {
        Unit::Metric => "metric",
        Unit::Imperial => "imperial",
    };

    let encoded_location = urlencoding::encode(&params.location);

    let request_url = format!(
        "{}?q={}&appid={}&units={}",
        OPENWEATHER_ENDPOINT, encoded_location, api_key, unit_query
    );

    let response = Client::new()
        .get(&request_url)
        .connect_timeout(Duration::from_secs(TIMEOUT_SECS))
        .header("User-Agent", "Mozilla/5.0 (compatible; noorle/1.0)")
        .send()
        .map_err(|e| Error::msg(format!("HTTP request failed: {}", e)))?;

    let status = response.status_code();
    if !(200..300).contains(&status) {
        return Err(Error::msg(format!("HTTP error: status code {}", status)));
    }

    let body_bytes = response.body()
        .map_err(|e| Error::msg(format!("Failed to read response body: {}", e)))?;

    let open_weather_response: OpenWeatherResponse = serde_json::from_slice(&body_bytes)
        .map_err(|e| Error::msg(format!("Failed to parse JSON response: {}", e)))?;

    let weather_response = WeatherResponse {
        location: open_weather_response.name,
        temperature: open_weather_response.main.temp,
        feels_like_temperature: open_weather_response.main.feels_like,
        wind_speed: Some(open_weather_response.wind.speed),
        wind_degrees: Some(open_weather_response.wind.deg as u32),
        humidity: Some(open_weather_response.main.humidity as u32),
        unit: params.unit,
        weather_conditions: open_weather_response.weather.into_iter().map(|w| w.description).collect(),
    };

    Ok(weather_response)
}

struct WeatherComponent;

impl Guest for WeatherComponent {
    fn check_weather(location: String, unit: Unit) -> Result<WeatherResponse, String> {
        let api_key = std::env::var("OPENWEATHER_API_KEY")
            .unwrap_or_else(|_| String::from(""));

        if api_key.is_empty() {
            return Err("OPENWEATHER_API_KEY environment variable not set".to_string());
        }

        let params = WeatherParams {
            location,
            unit,
        };

        get_weather(&api_key, params).map_err(|e| e.to_string())
    }
}

export!(WeatherComponent);