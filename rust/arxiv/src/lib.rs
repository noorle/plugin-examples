#![allow(unsafe_op_in_unsafe_fn)]

mod types;

use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use std::time::Duration;
use types::{ArxivPaper, DownloadResult};
use waki::Client;

wit_bindgen::generate!({
    world: "arxiv-component",
    path: "./wit",
});

const ARXIV_API_ENDPOINT: &str = "https://export.arxiv.org/api/query";
const TIMEOUT_SECS: u64 = 30;

fn search_arxiv(query: String, max_results: u32) -> Result<Vec<ArxivPaper>> {
    let max_results = max_results.min(100).max(1);

    let encoded_query = urlencoding::encode(&query);

    let url = format!(
        "{}?search_query={}&max_results={}&sortBy=submittedDate&sortOrder=descending",
        ARXIV_API_ENDPOINT, encoded_query, max_results
    );

    let response = Client::new()
        .get(&url)
        .connect_timeout(Duration::from_secs(TIMEOUT_SECS))
        .header("User-Agent", "Mozilla/5.0 (compatible; noorle-arxiv/1.0)")
        .send()
        .context("Failed to send request to arXiv API")?;

    let status = response.status_code();
    if !(200..300).contains(&status) {
        anyhow::bail!("arXiv API returned status code: {}", status);
    }

    let body_bytes = response.body()
        .context("Failed to read response body")?;

    let body = String::from_utf8(body_bytes)
        .context("Invalid UTF-8 in response")?;

    let feed = feed_rs::parser::parse(body.as_bytes())
        .context("Failed to parse arXiv feed")?;

    let mut papers = Vec::new();
    for entry in feed.entries {
        let paper_id = entry.id
            .split("/abs/")
            .last()
            .unwrap_or(&entry.id)
            .to_string();

        let authors = entry.authors
            .iter()
            .map(|author| author.name.clone())
            .collect();

        let categories = entry.categories
            .iter()
            .map(|cat| cat.term.clone())
            .collect();

        let url = entry.links
            .iter()
            .find(|l| l.rel == Some("alternate".to_string()))
            .map(|l| l.href.clone())
            .unwrap_or_else(|| format!("https://arxiv.org/abs/{}", paper_id));

        let pdf_url = entry.links
            .iter()
            .find(|l| l.media_type.as_deref() == Some("application/pdf"))
            .map(|l| l.href.clone())
            .unwrap_or_else(|| format!("https://arxiv.org/pdf/{}.pdf", paper_id));

        papers.push(ArxivPaper {
            paper_id,
            title: entry.title.map(|t| t.content).unwrap_or_default(),
            authors,
            abstract_text: entry.summary.map(|s| s.content).unwrap_or_default(),
            url,
            pdf_url,
            published_date: entry.published.unwrap_or(DateTime::<Utc>::MIN_UTC),
            updated_date: entry.updated.unwrap_or(DateTime::<Utc>::MIN_UTC),
            categories,
        });
    }

    Ok(papers)
}

fn download_arxiv_pdf(paper_id: String, save_path: String) -> Result<DownloadResult> {
    let clean_paper_id = if paper_id.contains('/') {
        paper_id.split('/').last().unwrap_or(&paper_id)
    } else {
        &paper_id
    };

    let pdf_url = format!("https://arxiv.org/pdf/{}", clean_paper_id);

    let response = Client::new()
        .get(&pdf_url)
        .connect_timeout(Duration::from_secs(TIMEOUT_SECS))
        .header("User-Agent", "Mozilla/5.0 (compatible; noorle-arxiv/1.0)")
        .header("Accept", "application/pdf")
        .send()
        .context("Failed to download PDF from arXiv")?;

    let status = response.status_code();
    if !(200..300).contains(&status) {
        return Ok(DownloadResult {
            success: false,
            file_path: None,
            error: Some(format!("Failed to download PDF: HTTP status {}", status)),
        });
    }

    let pdf_data = response.body()
        .context("Failed to read PDF data")?;

    if pdf_data.is_empty() {
        return Ok(DownloadResult {
            success: false,
            file_path: None,
            error: Some("Received empty PDF data from arXiv".to_string()),
        });
    }

    let save_dir = if save_path.is_empty() {
        "/tmp".to_string()
    } else {
        save_path.trim_end_matches('/').to_string()
    };

    let file_path = format!("{}/{}.pdf", save_dir, clean_paper_id);

    match std::fs::write(&file_path, &pdf_data) {
        Ok(_) => Ok(DownloadResult {
            success: true,
            file_path: Some(file_path),
            error: None,
        }),
        Err(e) => Ok(DownloadResult {
            success: false,
            file_path: None,
            error: Some(format!("Failed to write PDF to disk: {}", e)),
        }),
    }
}

struct ArxivComponent;

impl Guest for ArxivComponent {
    fn search(query: String, max_results: u32) -> Result<String, String> {
        match search_arxiv(query, max_results) {
            Ok(papers) => {
                serde_json::to_string(&papers)
                    .map_err(|e| format!("Failed to serialize results: {}", e))
            }
            Err(e) => Err(format!("Search failed: {}", e))
        }
    }

    fn download_pdf(paper_id: String, save_path: String) -> Result<String, String> {
        match download_arxiv_pdf(paper_id, save_path) {
            Ok(result) => {
                serde_json::to_string(&result)
                    .map_err(|e| format!("Failed to serialize result: {}", e))
            }
            Err(e) => Err(format!("Download failed: {}", e))
        }
    }
}

export!(ArxivComponent);