# Python Sandbox Plugin (Python) - Noorle Example

A reference implementation demonstrating sandboxed code execution in Noorle plugins using Python and the WebAssembly Component Model with WASI 0.2.

## Why This Example Matters

This Python sandbox plugin showcases patterns for building safe code execution environments:

- **Sandboxed Execution**: Shows how to safely execute arbitrary Python code in isolated WASM environments
- **Output Capture**: Demonstrates capturing stdout/stderr from executed code
- **Expression Evaluation**: Pattern for evaluating Python expressions and returning results
- **Error Handling**: Robust exception handling and error reporting for dynamic code execution
- **Component Interface Design**: Clean, documented APIs using WIT (WebAssembly Interface Types)

## Architecture & Technology Choices

**WebAssembly Component Model with WASI 0.2** provides secure, portable sandboxing with standardized system interfaces, making it ideal for code execution environments where isolation and security are critical.

**Python + componentize-py:**
- Uses the official `componentize-py` for Python-to-WASM compilation
- Leverages Python's built-in `exec()` and `eval()` for code execution
- Context managers for clean output redirection
- Native exception handling with Result types

**Why Python for Code Sandboxing:**
- Built-in `exec()` and `eval()` functions for dynamic code execution
- Excellent standard library with `contextlib` and `io` for output capture
- Simple exception handling that translates well to Result types
- Dynamic nature perfect for interactive code execution environments

## Code Execution Patterns

### Execute Statements with Output Capture

```python
def exec(self, statements: str) -> wit_world.Result[str, str]:
    buffer = io.StringIO()
    try:
        # Redirect stdout and stderr to our buffer
        with contextlib.redirect_stdout(buffer), contextlib.redirect_stderr(buffer):
            exec(statements)
        return Ok(buffer.getvalue())
    except Exception as e:
        return handle_exception(e)
```

**Why This Pattern:**
- Uses `io.StringIO()` for in-memory output buffering
- `contextlib.redirect_stdout/stderr` captures all print statements
- Clean exception handling with typed error messages
- Returns actual output that was printed

### Evaluate Expressions with JSON Serialization

```python
def eval(self, expression: str) -> wit_world.Result[str, str]:
    try:
        result = eval(expression)
        return Ok(json.dumps(result))
    except Exception as e:
        return handle_exception(e)
```

**Why This Pattern:**
- Uses Python's built-in `eval()` for expression evaluation
- JSON serialization ensures results are properly formatted
- Works with any JSON-serializable Python type
- Clean error propagation for syntax errors and runtime errors

### Exception Handling

```python
def handle_exception(e: Exception) -> Err[str]:
    message = str(e)
    if message == "":
        return Err(f"{type(e).__name__}")
    else:
        return Err(f"{type(e).__name__}: {message}")
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
# Test exec function with simple print
wasmtime run --invoke 'exec("print(\"Hello, World!\")")' dist/plugin.wasm

# Test exec with multiple statements
wasmtime run --invoke 'exec("for i in range(5):\n    print(i)")' dist/plugin.wasm

# Test eval with expression
wasmtime run --invoke 'eval("2 + 2")' dist/plugin.wasm

# Test eval with list comprehension
wasmtime run --invoke 'eval("[x**2 for x in range(10)]")' dist/plugin.wasm

# Test error handling
wasmtime run --invoke 'exec("1/0")' dist/plugin.wasm
```

## Project Structure

```
python-sandbox/
├── app.py               # Main plugin implementation
├── wit/
│   └── world.wit        # Component interface definition
├── pyproject.toml       # Python dependencies and metadata
├── noorle.yaml          # Plugin permissions and configuration
├── build.sh             # Build script (used by noorle CLI)
└── dist/                # Build output (created after build)
    └── plugin.wasm      # Compiled WASM component
```

## Key Dependencies

```toml
[project]
dependencies = [
    "componentize-py==0.17.2",  # Python-to-WASM compilation
]
```

**Runtime Dependencies:**
- `wit_world` - Generated bindings from WIT interface definitions
- `contextlib` - Built-in context managers for output redirection
- `io` - Built-in I/O utilities for StringIO
- `json` - Built-in JSON processing

## API Reference

### `exec(statements: string) -> result<string, string>`

Execute Python statements and capture stdout/stderr output.

**Parameters:**
- `statements`: Python code to execute (can be multiple lines/statements)

**Returns:**
Success: Captured output as string
```
"Hello, World!\n0\n1\n2\n"
```

Error: String describing the error
```
"ZeroDivisionError: division by zero"
```

**Examples:**
```python
# Simple print
exec("print('Hello')")  # Returns "Hello\n"

# Multiple statements
exec("for i in range(3):\n    print(i)")  # Returns "0\n1\n2\n"

# Error case
exec("1/0")  # Returns Err("ZeroDivisionError: division by zero")
```

### `eval(expression: string) -> result<string, string>`

Evaluate a Python expression and return the result as JSON.

**Parameters:**
- `expression`: Python expression to evaluate (single expression only)

**Returns:**
Success: JSON-serialized result
```
"4"
"[0, 1, 4, 9, 16]"
```

Error: String describing the error
```
"NameError: name 'undefined_var' is not defined"
```

**Examples:**
```python
# Simple arithmetic
eval("2 + 2")  # Returns "4"

# List comprehension
eval("[x**2 for x in range(5)]")  # Returns "[0, 1, 4, 9, 16]"

# Dictionary
eval("{'a': 1, 'b': 2}")  # Returns "{\"a\": 1, \"b\": 2}"

# Error case
eval("undefined_var")  # Returns Err("NameError: name 'undefined_var' is not defined")
```

## Python Implementation Features

### Result Types for Type Safety

```python
from wit_world.types import Ok, Err

# Success case
return Ok("output string")

# Error case
return Err("error message")
```

### Clean Exception Handling

```python
try:
    result = eval(expression)
    return Ok(json.dumps(result))
except Exception as e:
    return handle_exception(e)
```

## Implementation Notes

This implementation is inspired by the [componentize-py sandbox example](https://github.com/bytecodealliance/componentize-py/blob/main/examples/sandbox/guest.py) from the Bytecode Alliance, demonstrating clean patterns for code execution in WASM environments.

## Learning Outcomes

By studying this example, developers learn:

1. **Sandboxed Execution**: How to safely execute dynamic code in WASM environments
2. **Output Redirection**: Capturing stdout/stderr in Python using contextlib
3. **Result Types**: Using Component Model Result types for robust error handling
4. **Security Through Isolation**: Leveraging WASM's sandboxing for code execution safety
5. **Component Development**: Building interactive development tools as WASM components

## Use Cases

This pattern is ideal for:

- **Code Playgrounds**: Interactive Python learning environments
- **Data Processing**: Safe execution of user-defined data transformations
- **Calculator Services**: Mathematical expression evaluation
- **Scripting Engines**: Embedded Python scripting for applications
- **Testing Environments**: Isolated test execution sandboxes

## Best Practices

1. **Validate Input**: Always validate code input before execution
2. **Handle All Exceptions**: Use comprehensive try/except blocks
3. **Clear Error Messages**: Return informative error messages with exception types
4. **Use Result Types**: Leverage Ok/Err for explicit success/failure handling
5. **Test Edge Cases**: Verify behavior with syntax errors, runtime errors, and edge cases

This example serves as a foundation for building code execution environments, demonstrating how Python's dynamic nature and WASM's security can be combined to create safe, interactive computing platforms.
