use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Serialize, Deserialize)]
pub struct ExchangeRateResponse {
    pub base_currency: String,
    pub rates: HashMap<String, f64>,
    pub last_updated: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ConversionResponse {
    pub from_currency: String,
    pub to_currency: String,
    pub amount: f64,
    pub converted_amount: f64,
    pub exchange_rate: f64,
    pub last_updated: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CurrencyListResponse {
    pub currencies: HashMap<String, String>,
}