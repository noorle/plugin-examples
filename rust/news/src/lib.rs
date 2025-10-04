#![allow(unsafe_op_in_unsafe_fn)]

mod types;

use anyhow::{Context, Result};
use std::time::Duration;
use types::NewsApiResponse;
use waki::Client;

wit_bindgen::generate!({
    world: "news-component",
    path: "./wit",
});

const NEWSAPI_ENDPOINT: &str = "https://newsapi.org/v2/everything";
const TIMEOUT_SECS: u64 = 30;
const DEFAULT_PAGE_SIZE: u32 = 10;

fn search_news_internal(query: String) -> Result<NewsResponse> {
    // Get API key from environment variable
    let api_key = std::env::var("NEWSAPI_API_KEY")
        .context("NEWSAPI_API_KEY environment variable not set")?;

    if api_key.is_empty() {
        anyhow::bail!("NEWSAPI_API_KEY is empty");
    }

    // Encode the query parameter
    let encoded_query = urlencoding::encode(&query);

    // Build the request URL
    let request_url = format!(
        "{}?q={}&pageSize={}",
        NEWSAPI_ENDPOINT, encoded_query, DEFAULT_PAGE_SIZE
    );

    // Make the HTTP request
    let response = Client::new()
        .get(&request_url)
        .connect_timeout(Duration::from_secs(TIMEOUT_SECS))
        .header("x-api-key", &api_key)
        .header("User-Agent", "Mozilla/5.0 (compatible; noorle/1.0)")
        .send()
        .context("Failed to send request to NewsAPI")?;

    let status = response.status_code();

    // Handle rate limiting
    if status == 429 {
        anyhow::bail!("NewsAPI rate limit exceeded. Please try again later.");
    }

    // Handle authentication errors
    if status == 401 {
        anyhow::bail!("Invalid NewsAPI API key");
    }

    // Check for other HTTP errors
    if !(200..300).contains(&status) {
        anyhow::bail!("NewsAPI returned HTTP status code: {}", status);
    }

    // Read response body
    let body_bytes = response
        .body()
        .context("Failed to read response body")?;

    // Parse JSON response
    let api_response: NewsApiResponse = serde_json::from_slice(&body_bytes)
        .context("Failed to parse NewsAPI JSON response")?;

    // Convert to WIT-generated types
    let articles: Vec<Article> = api_response
        .articles
        .into_iter()
        .map(|article| Article {
            title: article.title,
            description: article.description,
            url: article.url,
            source: article.source.map(|s| Source { name: s.name }),
        })
        .collect();

    Ok(NewsResponse { articles })
}

struct NewsComponent;

impl Guest for NewsComponent {
    fn search_news(query: String) -> Result<NewsResponse, String> {
        if query.trim().is_empty() {
            return Err("Search query cannot be empty".to_string());
        }

        search_news_internal(query).map_err(|e| format!("News search failed: {}", e))
    }
}

export!(NewsComponent);
