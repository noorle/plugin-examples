#![allow(unsafe_op_in_unsafe_fn)]

use anyhow::{Error, Result};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::time::Duration;
use waki::Client;

wit_bindgen::generate!({
    world: "weather-component",
    path: "./wit",
});

const OPENWEATHER_ENDPOINT: &str = "https://api.openweathermap.org/data/2.5/weather";
const TIMEOUT_SECS: u64 = 10;

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Unit {
    #[serde(rename = "metric")]
    Metric,
    #[serde(rename = "imperial")]
    Imperial,
}

#[derive(Deserialize)]
pub struct WeatherParams {
    pub location: String,
    pub unit: Unit,
}

#[derive(Serialize)]
pub struct WeatherResponse {
    pub location: String,
    pub temperature: f64,
    pub feels_like_temperature: f64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub wind_speed: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub wind_degrees: Option<usize>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub humidity: Option<usize>,
    pub unit: Unit,
    pub weather_conditions: Vec<String>,
}

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

    let body = String::from_utf8(body_bytes)
        .map_err(|e| Error::msg(format!("Invalid UTF-8 in response: {}", e)))?;

    let weather_data: Value = serde_json::from_str(&body)
        .map_err(|e| Error::msg(format!("Failed to parse JSON response: {}", e)))?;

    let weather_response = WeatherResponse {
        location: weather_data["name"]
            .as_str()
            .unwrap_or_default()
            .to_string(),
        temperature: weather_data["main"]["temp"]
            .as_f64()
            .ok_or_else(|| Error::msg("Error parsing temperature"))?,
        feels_like_temperature: weather_data["main"]["feels_like"]
            .as_f64()
            .ok_or_else(|| Error::msg("Error parsing feels_like temperature"))?,
        wind_speed: weather_data["wind"]["speed"].as_f64(),
        wind_degrees: weather_data["wind"]["deg"].as_u64().map(|d| d as usize),
        humidity: weather_data["main"]["humidity"]
            .as_u64()
            .map(|h| h as usize),
        unit: params.unit,
        weather_conditions: weather_data["weather"]
            .as_array()
            .map(|ws| {
                ws.iter()
                    .filter_map(|w| w["description"].as_str().map(str::to_owned))
                    .collect()
            })
            .unwrap_or_default(),
    };

    Ok(weather_response)
}

struct WeatherComponent;

impl Guest for WeatherComponent {
    fn check_weather(location: String, unit: String) -> Result<String, String> {
        let api_key = std::env::var("OPENWEATHER_API_KEY")
            .unwrap_or_else(|_| String::from(""));

        if api_key.is_empty() {
            return Err("OPENWEATHER_API_KEY environment variable not set".to_string());
        }

        let unit_enum = match unit.to_lowercase().as_str() {
            "metric" => Unit::Metric,
            "imperial" => Unit::Imperial,
            _ => Unit::Metric,
        };

        let params = WeatherParams {
            location,
            unit: unit_enum,
        };

        match get_weather(&api_key, params) {
            Ok(weather) => serde_json::to_string(&weather)
                .map_err(|e| format!("Failed to serialize response: {}", e)),
            Err(e) => Err(format!("Failed to fetch weather: {}", e)),
        }
    }
}

export!(WeatherComponent);