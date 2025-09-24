# Contributing to Noorle Plugin Examples

Thank you for your interest in contributing to the Noorle Plugin Examples repository! These examples help developers learn how to build plugins for the Noorle platform using WebAssembly and various programming languages.

## How to Contribute

We welcome contributions in several areas:

### 1. New Plugin Examples
- Implement practical, real-world use cases
- Demonstrate unique WASI capabilities or patterns
- Show integration with popular APIs or services

### 2. Language Implementations
- Add implementations of existing plugins in new languages
- Ensure consistency with other language versions
- Follow language-specific best practices

### 3. Improvements to Existing Examples
- Bug fixes and performance optimizations
- Better error handling
- Code clarity and documentation improvements
- Update dependencies to latest stable versions

### 4. Documentation
- Improve READMEs with clearer explanations
- Add inline code comments for complex logic
- Create tutorials or guides
- Fix typos and improve clarity

## Development Process

### 1. Fork and Clone
```bash
# Fork the repository on GitHub, then:
git clone https://github.com/YOUR_USERNAME/plugin-examples
cd plugin-examples
```

### 2. Create a Branch
```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/issue-description
```

### 3. Make Your Changes
Follow the project structure and coding standards (see below).

### 4. Test Your Changes
```bash
# Build the plugin
noorle plugin build

# Test with wasmtime (example)
wasmtime run --wasi http \
  --invoke 'your-function("params")' dist/plugin.wasm
```

### 5. Commit Your Changes
```bash
git add .
git commit -m "feat: add new currency converter plugin"
# or
git commit -m "fix: handle network timeout in weather plugin"
```

Follow conventional commit messages:
- `feat:` for new features
- `fix:` for bug fixes
- `docs:` for documentation changes
- `refactor:` for code refactoring
- `test:` for test additions/changes
- `chore:` for maintenance tasks

### 6. Push and Create Pull Request
```bash
git push origin your-branch-name
```
Then create a Pull Request on GitHub.

## Project Structure Standards

### Directory Structure
```
language/plugin-name/
├── src/ or app.*        # Main implementation file(s)
├── wit/
│   └── world.wit        # WIT interface definition
├── noorle.yaml          # Plugin configuration
├── build.sh             # Build script
├── .env.example         # Environment template (if needed)
├── README.md            # Comprehensive documentation
└── dist/                # Build output (git ignored)
```

### Required Files

#### noorle.yaml
Must specify:
- Plugin metadata (name, version, description)
- WASI permissions required
- Environment variables used

#### world.wit
Must include:
- Clear function signatures
- Descriptive parameter names
- Result types for error handling
- Documentation comments

#### README.md
Must contain:
- Plugin overview and purpose
- Features list
- Architecture explanation
- Build and deployment instructions
- API reference with examples
- Learning outcomes

#### build.sh
Must:
- Be executable (`chmod +x build.sh`)
- Handle dependencies installation
- Compile to WASM component
- Output to `dist/plugin.wasm`

## Code Standards

### General Principles
1. **Security First**: Never hardcode secrets or API keys
2. **Error Handling**: Always return meaningful error messages
3. **Documentation**: Comment complex logic and algorithms
4. **Testing**: Include test commands in README
5. **Idiomatic Code**: Follow language-specific conventions

### Language-Specific Guidelines

#### Rust
- Use `cargo fmt` and `cargo clippy`
- Prefer `anyhow` for error handling in examples
- Use `waki` for HTTP in WASI environments
- Target `wasm32-wasip2`

#### Go
- Use `gofmt` for formatting
- Follow standard Go project layout
- Use TinyGo for compilation
- Target `wasip2`

#### Python
- Follow PEP 8 style guide
- Use type hints where appropriate
- Use `componentize-py` for WASM compilation

#### JavaScript/TypeScript
- Use ES modules
- Include `package-lock.json`
- For TypeScript, use strict mode
- Use ComponentizeJS for WASM compilation

## Adding a New Plugin Example

### 1. Choose a Practical Use Case
- Should demonstrate real-world functionality
- Avoid duplicating existing examples
- Consider common developer needs

### 2. Implement Core Functionality
- Start with one language implementation
- Focus on clean, understandable code
- Include proper error handling

### 3. Create Comprehensive Documentation
- Explain why this example matters
- Document all functions and parameters
- Include usage examples
- Add troubleshooting section if needed

### 4. Test Thoroughly
```bash
# Build
noorle plugin build

# Test each exported function
wasmtime run --wasi http \
  --invoke 'function-name("params")' dist/plugin.wasm

# Verify error cases
# Test with invalid inputs
# Check timeout handling
```

### 5. Add to Main README
Update the root `README.md` to include your new example in the "Available Examples" section.

## Pull Request Guidelines

### PR Title
Use a clear, descriptive title:
- ✅ "Add QR code generator plugin in Rust"
- ✅ "Fix timeout handling in weather plugin"
- ❌ "Updates"
- ❌ "Fixed stuff"

### PR Description
Include:
- **What**: Brief description of changes
- **Why**: Motivation and use case
- **How**: Technical approach taken
- **Testing**: How you tested the changes
- **Screenshots**: If applicable (for output examples)

### Example PR Description
```markdown
## What
Added a new PDF generator plugin that creates PDFs from Markdown.

## Why
Many developers need to generate PDFs from structured content.
This example shows how to handle binary output from WASM plugins.

## How
- Uses `wasi-pdf` library for PDF generation
- Implements streaming for large documents
- Returns base64-encoded PDF data

## Testing
- Tested with various Markdown inputs
- Verified PDF output in multiple viewers
- Tested error handling with malformed input
```

## Review Process

1. **Automated Checks**: Ensure your code builds successfully
2. **Code Review**: Maintainers will review for:
   - Code quality and clarity
   - Security best practices
   - Consistency with existing examples
   - Documentation completeness
3. **Testing**: Reviewers may test your plugin locally
4. **Feedback**: Address any requested changes
5. **Merge**: Once approved, your PR will be merged

## Questions and Support

- **Questions**: Open an issue with the "question" label
- **Bugs**: Open an issue with reproduction steps
- **Ideas**: Open an issue with the "enhancement" label
- **Discussions**: Use GitHub Discussions for general topics

## License

By contributing to this repository, you agree that your contributions will be licensed under the MIT License with additional terms for Noorle Platform integration as specified in the [LICENSE](LICENSE) file.

Your contributions may be used by Noorle for:
- Platform documentation
- Tutorial content
- Promotional materials
- Integration into Noorle services

## Recognition

We value all contributions! Contributors will be:
- Listed in release notes
- Mentioned in commit messages
- Credited in documentation where applicable

## Code of Conduct

### Our Standards
- Be respectful and inclusive
- Welcome newcomers and help them learn
- Accept constructive criticism gracefully
- Focus on what's best for the community
- Show empathy towards others

### Unacceptable Behavior
- Harassment or discrimination
- Trolling or insulting comments
- Publishing others' private information
- Other unprofessional conduct

## Thank You!

Your contributions help make Noorle plugin development accessible to developers worldwide. We appreciate your time and effort in improving these examples!

Happy coding! 🚀