#![allow(unsafe_op_in_unsafe_fn)]

mod types;

use anyhow::{Context, Result};
use serde_json::Value;
use std::collections::HashMap;
use std::time::Duration;
use types::{ConversionResponse, CurrencyListResponse, ExchangeRateResponse};
use waki::Client;

wit_bindgen::generate!({
    world: "exchange-rate-component",
    path: "./wit",
});

const PRIMARY_ENDPOINT: &str = "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies";
const FALLBACK_ENDPOINT: &str = "https://latest.currency-api.pages.dev/v1/currencies";
const TIMEOUT_SECS: u64 = 30;

fn get_exchange_rates_internal(base_currency: String, target_currencies: String) -> Result<ExchangeRateResponse> {
    let base_currency = base_currency.to_lowercase();

    let encoded_base = urlencoding::encode(&base_currency);

    let request_url = format!("{}/{}.json", PRIMARY_ENDPOINT, encoded_base);

    let response = Client::new()
        .get(&request_url)
        .connect_timeout(Duration::from_secs(TIMEOUT_SECS))
        .header("User-Agent", "Mozilla/5.0 (compatible; noorle/1.0)")
        .send()
        .or_else(|_| {
            let fallback_url = format!("{}/{}.json", FALLBACK_ENDPOINT, encoded_base);
            Client::new()
                .get(&fallback_url)
                .connect_timeout(Duration::from_secs(TIMEOUT_SECS))
                .header("User-Agent", "Mozilla/5.0 (compatible; noorle/1.0)")
                .send()
        })
        .context("Both primary and fallback API requests failed")?;

    let status = response.status_code();
    if !(200..300).contains(&status) {
        anyhow::bail!("Exchange rate API returned status code: {}", status);
    }

    let body_bytes = response.body()
        .context("Failed to read response body")?;

    let body = String::from_utf8(body_bytes)
        .context("Invalid UTF-8 in response")?;

    let exchange_data: Value = serde_json::from_str(&body)
        .context("Failed to parse JSON response")?;

    let last_updated = exchange_data["date"]
        .as_str()
        .unwrap_or("unknown")
        .to_string();

    let all_rates = exchange_data[&base_currency]
        .as_object()
        .ok_or_else(|| anyhow::anyhow!("No exchange rates found in response"))?;

    let mut rates = HashMap::new();

    if !target_currencies.is_empty() {
        let target_list: Vec<String> = target_currencies
            .split(',')
            .map(|s| s.trim().to_lowercase())
            .filter(|s| !s.is_empty())
            .collect();

        for target in target_list {
            if let Some(rate_value) = all_rates.get(&target) {
                if let Some(rate) = rate_value.as_f64() {
                    rates.insert(target, rate);
                }
            }
        }
    } else {
        for (currency, rate_value) in all_rates {
            if let Some(rate) = rate_value.as_f64() {
                rates.insert(currency.clone(), rate);
            }
        }
    }

    Ok(ExchangeRateResponse {
        base_currency,
        rates,
        last_updated,
    })
}

fn convert_currency_internal(from_currency: String, to_currency: String, amount: f64) -> Result<ConversionResponse> {
    let from_currency = from_currency.to_lowercase();
    let to_currency = to_currency.to_lowercase();

    if from_currency == to_currency {
        return Ok(ConversionResponse {
            from_currency,
            to_currency,
            amount,
            converted_amount: amount,
            exchange_rate: 1.0,
            last_updated: "N/A".to_string(),
        });
    }

    let encoded_from = urlencoding::encode(&from_currency);
    let request_url = format!("{}/{}.json", PRIMARY_ENDPOINT, encoded_from);

    let response = Client::new()
        .get(&request_url)
        .connect_timeout(Duration::from_secs(TIMEOUT_SECS))
        .header("User-Agent", "Mozilla/5.0 (compatible; noorle/1.0)")
        .send()
        .or_else(|_| {
            let fallback_url = format!("{}/{}.json", FALLBACK_ENDPOINT, encoded_from);
            Client::new()
                .get(&fallback_url)
                .connect_timeout(Duration::from_secs(TIMEOUT_SECS))
                .header("User-Agent", "Mozilla/5.0 (compatible; noorle/1.0)")
                .send()
        })
        .context("Both primary and fallback API requests failed")?;

    let status = response.status_code();
    if !(200..300).contains(&status) {
        anyhow::bail!("Exchange rate API returned status code: {}", status);
    }

    let body_bytes = response.body()
        .context("Failed to read response body")?;

    let body = String::from_utf8(body_bytes)
        .context("Invalid UTF-8 in response")?;

    let exchange_data: Value = serde_json::from_str(&body)
        .context("Failed to parse JSON response")?;

    let last_updated = exchange_data["date"]
        .as_str()
        .unwrap_or("unknown")
        .to_string();

    let rates = exchange_data[&from_currency]
        .as_object()
        .ok_or_else(|| anyhow::anyhow!("No exchange rates found in response"))?;

    let exchange_rate = rates[&to_currency]
        .as_f64()
        .ok_or_else(|| anyhow::anyhow!("Exchange rate not found for {} to {}", from_currency, to_currency))?;

    let converted_amount = amount * exchange_rate;

    Ok(ConversionResponse {
        from_currency,
        to_currency,
        amount,
        converted_amount,
        exchange_rate,
        last_updated,
    })
}

fn list_currencies_internal() -> Result<CurrencyListResponse> {
    let request_url = format!("{}.json", PRIMARY_ENDPOINT);

    let response = Client::new()
        .get(&request_url)
        .connect_timeout(Duration::from_secs(TIMEOUT_SECS))
        .header("User-Agent", "Mozilla/5.0 (compatible; noorle/1.0)")
        .send()
        .or_else(|_| {
            let fallback_url = format!("{}.json", FALLBACK_ENDPOINT);
            Client::new()
                .get(&fallback_url)
                .connect_timeout(Duration::from_secs(TIMEOUT_SECS))
                .header("User-Agent", "Mozilla/5.0 (compatible; noorle/1.0)")
                .send()
        })
        .context("Both primary and fallback API requests failed")?;

    let status = response.status_code();
    if !(200..300).contains(&status) {
        anyhow::bail!("Currencies API returned status code: {}", status);
    }

    let body_bytes = response.body()
        .context("Failed to read response body")?;

    let body = String::from_utf8(body_bytes)
        .context("Invalid UTF-8 in response")?;

    let currencies_data: Value = serde_json::from_str(&body)
        .context("Failed to parse JSON response")?;

    let currencies_obj = currencies_data
        .as_object()
        .ok_or_else(|| anyhow::anyhow!("Invalid currencies response format"))?;

    let mut currencies = HashMap::new();
    for (code, name_value) in currencies_obj {
        if let Some(name) = name_value.as_str() {
            currencies.insert(code.clone(), name.to_string());
        }
    }

    Ok(CurrencyListResponse { currencies })
}

struct ExchangeRateComponent;

impl Guest for ExchangeRateComponent {
    fn get_exchange_rates(base_currency: String, target_currencies: String) -> Result<String, String> {
        match get_exchange_rates_internal(base_currency, target_currencies) {
            Ok(rates) => {
                serde_json::to_string(&rates)
                    .map_err(|e| format!("Failed to serialize results: {}", e))
            }
            Err(e) => {
                Err(format!("Exchange rate request failed: {}", e))
            }
        }
    }

    fn convert_currency(from_currency: String, to_currency: String, amount: f64) -> Result<String, String> {
        match convert_currency_internal(from_currency, to_currency, amount) {
            Ok(conversion) => {
                serde_json::to_string(&conversion)
                    .map_err(|e| format!("Failed to serialize result: {}", e))
            }
            Err(e) => {
                Err(format!("Currency conversion failed: {}", e))
            }
        }
    }

    fn list_currencies() -> Result<String, String> {
        match list_currencies_internal() {
            Ok(currencies) => {
                serde_json::to_string(&currencies)
                    .map_err(|e| format!("Failed to serialize currencies: {}", e))
            }
            Err(e) => {
                Err(format!("Failed to list currencies: {}", e))
            }
        }
    }
}

export!(ExchangeRateComponent);