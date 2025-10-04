use serde::Deserialize;

/// Response from NewsAPI.org
#[derive(Debug, Deserialize)]
pub struct NewsApiResponse {
    pub status: String,
    pub articles: Vec<NewsApiArticle>,
}

/// Article from NewsAPI.org
#[derive(Debug, Deserialize)]
pub struct NewsApiArticle {
    pub source: Option<NewsApiSource>,
    pub title: Option<String>,
    pub description: Option<String>,
    pub url: Option<String>,
}

/// Source information from NewsAPI.org
#[derive(Debug, Deserialize)]
pub struct NewsApiSource {
    pub name: Option<String>,
}
