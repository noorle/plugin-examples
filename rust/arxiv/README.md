# ArXiv Plugin (Rust) - Noorle Example

A Rust WebAssembly plugin for the Noorle platform that provides arXiv paper search and PDF download capabilities.

## Features

- **Search arXiv**: Query the arXiv repository for academic papers with customizable result limits
- **Download PDFs**: Download paper PDFs directly from arXiv to specified locations
- **Structured Data**: Returns detailed paper metadata including titles, authors, abstracts, categories, and dates
- **Fast & Efficient**: Built with Rust for optimal WASM performance

## Why This Example Matters

This arXiv plugin demonstrates practical patterns for building research-oriented Noorle plugins:

- **Feed Parsing**: Shows how to parse Atom/RSS feeds from academic APIs
- **PDF Download**: Implements binary file download and storage from WASM
- **Complex Data Structures**: Handling rich metadata with dates, arrays, and nested objects
- **API Integration**: Interfacing with academic repositories and content providers

## Architecture & Technology Choices

**WebAssembly Component Model with WASI 0.2** provides secure, portable sandboxing with standardized system interfaces.

**Key Libraries:**
- `feed-rs`: Robust Atom/RSS feed parsing for academic content
- `waki`: WASI-compatible HTTP client for API requests
- `chrono`: Date/time handling for publication timestamps
- `serde`: JSON serialization for structured data exchange

## Development & Testing

### Build and Deploy
```bash
# Build the plugin (creates WASM component)
noorle plugin build

# Deploy to Noorle platform
noorle plugin deploy
```

### Local Testing with wasmtime
```bash
# Test search function
wasmtime run --wasi http \
  --invoke 'search("quantum computing", 5)' dist/plugin.wasm

# Test PDF download (requires filesystem access)
wasmtime run --wasi http --dir /tmp \
  --invoke 'download-pdf("2301.08727", "/tmp")' dist/plugin.wasm
```

## Project Structure

```
arxiv/
├── src/
│   ├── lib.rs           # Main plugin implementation
│   └── types.rs         # Data structures for arXiv papers
├── wit/
│   └── world.wit        # Component interface definition
├── Cargo.toml           # Rust dependencies and metadata
├── noorle.yaml          # Plugin permissions and configuration
├── build.sh             # Build script (used by noorle CLI)
└── dist/                # Build output (created after build)
    └── plugin.wasm      # Compiled WASM component
```

## API Reference

### `search(query: string, max-results: u32) -> result<string, string>`

Search for papers on arXiv matching the given query.

**Parameters:**
- `query`: Search terms (e.g., "quantum computing", "machine learning")
- `max-results`: Maximum number of results to return (1-100, default: 10)

**Returns:**
Success: JSON string containing array of paper objects with:
- `paper_id`: arXiv identifier
- `title`: Paper title
- `authors`: Array of author names
- `abstract_text`: Paper abstract
- `url`: Web URL to paper page
- `pdf_url`: Direct PDF download URL
- `published_date`: Publication date (ISO 8601)
- `updated_date`: Last update date (ISO 8601)
- `categories`: arXiv subject categories

Error: String describing what went wrong

**Example Response:**
```json
[
  {
    "paper_id": "2509.16200v1",
    "title": "Exploring confinement transitions in Z2 lattice gauge theories...",
    "authors": ["Matjaž Kebrič", "Lin Su", "Alexander Douglas"],
    "abstract_text": "Confinement of particles into bound states is a phenomenon...",
    "url": "http://arxiv.org/abs/2509.16200v1",
    "pdf_url": "http://arxiv.org/pdf/2509.16200v1",
    "published_date": "2025-09-19T17:58:55Z",
    "categories": ["cond-mat.quant-gas", "quant-ph"]
  }
]
```

### `download-pdf(paper-id: string, save-path: string) -> result<string, string>`

Download a PDF paper from arXiv.

**Parameters:**
- `paper-id`: arXiv paper ID (e.g., "2301.08727")
- `save-path`: Directory to save the PDF (e.g., "/tmp")

**Returns:**
Success: JSON string with download result:
```json
{"success": true, "file_path": "/path/to/file.pdf"}
```

Error: String describing what went wrong

## Key Dependencies

```toml
[dependencies]
wit-bindgen = "0.46.0"    # Component Model bindings generation
anyhow = "1.0"            # Error handling
serde = { version = "1.0", features = ["derive"] }  # JSON serialization
serde_json = "1.0"        # JSON parsing
waki = "0.5"              # WASI HTTP client
urlencoding = "2.1"       # URL encoding for API parameters
feed-rs = "1.5"           # Atom/RSS feed parsing
chrono = { version = "0.4", features = ["serde"] }  # Date/time handling
```

## Learning Outcomes

By studying this example, developers learn:

1. **Feed Parsing**: How to process Atom/RSS feeds in WASM components
2. **Binary File Handling**: Downloading and saving PDFs from WASM
3. **Complex Data Processing**: Working with academic metadata structures
4. **Date/Time Handling**: Managing temporal data in WASM environments
5. **Error Recovery**: Graceful handling of API failures and malformed data

This example serves as a foundation for building research tools, academic integrations, and content aggregation plugins.