# JavaScript Sandbox Plugin (JavaScript) - Noorle Example

A reference implementation demonstrating sandboxed code execution in Noorle plugins using JavaScript and the WebAssembly Component Model with WASI 0.2.

## Why This Example Matters

This JavaScript sandbox plugin showcases patterns for building safe code execution environments:

- **Sandboxed Execution**: Shows how to safely execute arbitrary JavaScript code in isolated WASM environments
- **Console Output Capture**: Demonstrates capturing console.log/error/warn output from executed code
- **Expression Evaluation**: Pattern for evaluating JavaScript expressions and returning JSON results
- **Error Handling**: Robust exception handling and error reporting for dynamic code execution
- **Component Interface Design**: Clean, documented APIs using WIT (WebAssembly Interface Types)

## Architecture & Technology Choices

**WebAssembly Component Model with WASI 0.2** provides secure, portable sandboxing with standardized system interfaces, making it ideal for code execution environments where isolation and security are critical.

**JavaScript + componentize-js:**
- Uses the official `componentize-js` for JavaScript-to-WASM compilation
- Powered by StarlingMonkey runtime (SpiderMonkey-based JS engine in WASM)
- Native `fetch()` API support for HTTP requests
- Custom console capture for output redirection
- Standard JavaScript features in a sandboxed environment

**Why JavaScript for Code Sandboxing:**
- Built-in `Function` constructor for dynamic code evaluation
- Familiar `console.log` API for output
- Easy exception handling that translates to Result types
- Native JSON support for serialization
- Dynamic nature perfect for interactive code execution environments

## Code Execution Patterns

### Execute Statements with Console Capture

```javascript
export function execCode(statements) {
  const capture = new ConsoleCapture();

  try {
    // Create a function with the statements and custom console
    const fn = Function('console', `"use strict"; ${statements}`);

    // Execute with captured console
    fn(capture);

    return capture.getOutput();
  } catch (error) {
    const errorName = error.name || 'Error';
    const errorMessage = error.message || '';
    throw `${errorName}: ${errorMessage}`;
  }
}
```

**Why This Pattern:**
- Uses `Function` constructor for isolated code execution
- Custom `ConsoleCapture` class intercepts console methods
- Strict mode prevents unsafe operations
- Throws plain strings for Result type compatibility

### Evaluate Expressions with JSON Serialization

```javascript
export function evalExpr(expression) {
  try {
    // Use Function constructor to evaluate expression in isolated scope
    const result = Function(`"use strict"; return (${expression})`)();
    return JSON.stringify(result);
  } catch (error) {
    const errorName = error.name || 'Error';
    const errorMessage = error.message || '';
    throw `${errorName}: ${errorMessage}`;
  }
}
```

**Why This Pattern:**
- Uses `Function` constructor with `return` for expression evaluation
- JSON serialization ensures results are properly formatted
- Works with any JSON-serializable JavaScript value
- Clean error propagation for syntax and runtime errors

### Console Capture Implementation

```javascript
class ConsoleCapture {
  constructor() {
    this.logs = [];
  }

  log(...args) {
    this.logs.push(args.map(arg => String(arg)).join(' '));
  }

  getOutput() {
    return this.logs.join('\n') + (this.logs.length > 0 ? '\n' : '');
  }
}
```

## Security Considerations

This plugin demonstrates **sandboxed execution** through:

- **WASM Isolation**: Code runs in a WebAssembly sandbox with no native system access
- **No Network Access**: No permissions granted for network operations
- **No File System Access**: No permissions granted for file operations
- **No Environment Variables**: No access to host environment
- **Pure Computation**: Only CPU and memory are available to executed code

**Important**: While WASM provides strong isolation, always validate and sanitize user input before execution in production environments.

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
# Test exec-code function with simple console.log
wasmtime run --wasi cli --wasi http \
  --invoke 'exec-code("console.log(\"Hello, World!\")")' dist/plugin.wasm

# Test exec-code with multiple statements
wasmtime run --wasi cli --wasi http \
  --invoke 'exec-code("for (let i = 0; i < 5; i++) console.log(i)")' dist/plugin.wasm

# Test eval-expr with expression
wasmtime run --wasi cli --wasi http \
  --invoke 'eval-expr("2 + 2")' dist/plugin.wasm

# Test eval-expr with array operation
wasmtime run --wasi cli --wasi http \
  --invoke 'eval-expr("[1, 2, 3].map(x => x ** 2)")' dist/plugin.wasm

# Test error handling
wasmtime run --wasi cli --wasi http \
  --invoke 'exec-code("throw new Error(\"test error\")")' dist/plugin.wasm
```

**Note**: The `--wasi cli --wasi http` flags are required because componentize-js includes WASI interfaces for console and standard JavaScript APIs, even though this plugin doesn't use HTTP.

## Project Structure

```
javascript-sandbox/
├── app.js               # Main plugin implementation
├── wit/
│   └── world.wit        # Component interface definition
├── package.json         # Node.js dependencies and metadata
├── noorle.yaml          # Plugin permissions and configuration
├── build.sh             # Build script (used by noorle CLI)
└── dist/                # Build output (created after build)
    └── plugin.wasm      # Compiled WASM component
```

## Key Dependencies

```json
{
  "dependencies": {
    "@bytecodealliance/componentize-js": "0.19.1",
    "@bytecodealliance/jco": "1.15.0"
  }
}
```

**Runtime Dependencies:**
- StarlingMonkey - SpiderMonkey-based JavaScript runtime for WASM
- WASI CLI - Console and stdio interfaces
- WASI Clocks - For `Date` objects (even if unused)

## API Reference

### `exec-code(statements: string) -> result<string, string>`

Execute JavaScript statements and capture console output.

**Parameters:**
- `statements`: JavaScript code to execute (can be multiple lines/statements)

**Returns:**
Success: Captured console output as string
```
"Hello, World!\n0\n1\n2\n"
```

Error: String describing the error
```
"Error: test error"
```

**Examples:**
```javascript
// Simple console.log
exec-code("console.log('Hello')")  // Returns "Hello\n"

// Multiple statements
exec-code("for (let i = 0; i < 3; i++) console.log(i)")  // Returns "0\n1\n2\n"

// Error case
exec-code("throw new Error('test')")  // Returns Err("Error: test")
```

### `eval-expr(expression: string) -> result<string, string>`

Evaluate a JavaScript expression and return the result as JSON.

**Parameters:**
- `expression`: JavaScript expression to evaluate (single expression only)

**Returns:**
Success: JSON-serialized result
```
"4"
"[1,4,9]"
```

Error: String describing the error
```
"ReferenceError: undefinedVar is not defined"
```

**Examples:**
```javascript
// Simple arithmetic
eval-expr("2 + 2")  // Returns "4"

// Array methods
eval-expr("[1, 2, 3].map(x => x ** 2)")  // Returns "[1,4,9]"

// Object literals
eval-expr("{a: 1, b: 2}")  // Returns "{\"a\":1,\"b\":2}"

// Error case
eval-expr("undefinedVar")  // Returns Err("ReferenceError: undefinedVar is not defined")
```

## JavaScript Implementation Features

### Function Constructor for Isolation

```javascript
// Evaluate with isolated scope
const result = Function(`"use strict"; return (${expression})`)();

// Execute with custom console
const fn = Function('console', `"use strict"; ${statements}`);
fn(capture);
```

### Result Types for Type Safety

For `result<string, string>` in componentize-js:
- **Success**: Return the string value directly
- **Error**: Throw a plain string (not Error object)

```javascript
// Success case
return "output string";

// Error case
throw "error message";
```

### Console Capture Pattern

```javascript
class ConsoleCapture {
  constructor() { this.logs = []; }

  log(...args) {
    this.logs.push(args.map(arg => String(arg)).join(' '));
  }

  getOutput() {
    return this.logs.join('\n') + (this.logs.length > 0 ? '\n' : '');
  }
}
```

## Implementation Notes

**Key implementation details:**
- Function names: `exec-code` and `eval-expr` to avoid JavaScript reserved keywords in strict mode
- Console capture using custom `ConsoleCapture` class to intercept console methods
- Uses `Function` constructor for isolated code execution with strict mode

## Learning Outcomes

By studying this example, developers learn:

1. **Sandboxed Execution**: How to safely execute dynamic code in WASM environments
2. **Console Redirection**: Capturing console output in JavaScript using custom objects
3. **Result Types**: Using Component Model Result types with componentize-js
4. **Security Through Isolation**: Leveraging WASM's sandboxing for code execution safety
5. **Component Development**: Building interactive development tools as WASM components

## Use Cases

This pattern is ideal for:

- **Code Playgrounds**: Interactive JavaScript learning environments
- **Data Processing**: Safe execution of user-defined data transformations
- **Calculator Services**: Mathematical expression evaluation
- **Scripting Engines**: Embedded JavaScript scripting for applications
- **Testing Environments**: Isolated test execution sandboxes

## Best Practices

1. **Validate Input**: Always validate code input before execution
2. **Handle All Exceptions**: Use comprehensive try/catch blocks
3. **Clear Error Messages**: Return informative error messages with exception types
4. **Use Result Types**: Throw plain strings for error cases in componentize-js
5. **Test Edge Cases**: Verify behavior with syntax errors, runtime errors, and edge cases

## JavaScript-Specific Notes

- **Strict Mode**: Always use `"use strict"` to prevent unsafe operations
- **Error Handling**: Throw plain strings (not Error objects) for Result types
- **JSON Serialization**: `JSON.stringify(Infinity)` returns `"null"` (not an error)
- **Division by Zero**: JavaScript `1/0` returns `Infinity` (doesn't throw an error)
- **WASI Requirements**: ComponentizeJS includes WASI interfaces by design, requiring `--wasi cli --wasi http` flags for local testing

This example serves as a foundation for building code execution environments, demonstrating how JavaScript's dynamic nature and WASM's security can be combined to create safe, interactive computing platforms.
