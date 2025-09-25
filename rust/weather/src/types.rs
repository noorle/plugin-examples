use serde::{Deserialize, Serialize};

impl<'de> Deserialize<'de> for crate::Unit {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let s = String::deserialize(deserializer)?;
        match s.as_str() {
            "metric" => Ok(crate::Unit::Metric),
            "imperial" => Ok(crate::Unit::Imperial),
            _ => Err(serde::de::Error::custom(format!("unknown unit: {}", s))),
        }
    }
}

impl Serialize for crate::Unit {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        match self {
            crate::Unit::Metric => serializer.serialize_str("metric"),
            crate::Unit::Imperial => serializer.serialize_str("imperial"),
        }
    }
}

#[derive(Deserialize)]
pub struct WeatherParams {
    pub location: String,
    pub unit: crate::Unit,
}

#[derive(Deserialize)]
pub struct OpenWeatherMain {
    pub temp: f64,
    pub feels_like: f64,
    pub humidity: usize,
}

#[derive(Deserialize)]
pub struct OpenWeatherWind {
    pub speed: f64,
    pub deg: usize,
}

#[derive(Deserialize)]
pub struct OpenWeatherWeather {
    pub description: String,
}

#[derive(Deserialize)]
pub struct OpenWeatherResponse {
    pub name: String,
    pub main: OpenWeatherMain,
    pub wind: OpenWeatherWind,
    pub weather: Vec<OpenWeatherWeather>,
}