# Additional Standard Library Modules

This directory contains Python standard library modules that should be bundled into the WASM component.

## How It Works

The `__init__.py` file in this directory automatically discovers and imports all `.py` files, ensuring they are bundled by `componentize-py` during the build process.

## Adding New Modules

To add additional Python standard library modules to your WASM build:

1. **Find the module on your system:**
   ```bash
   python3 -c "import MODULE_NAME; print(MODULE_NAME.__file__)"
   ```

2. **Copy it to this directory:**
   ```bash
   cp /path/to/module.py additional_modules/
   ```

3. **Rebuild:**
   ```bash
   ./build.sh
   ```

That's it! No code changes needed - the module is automatically discovered and bundled.

## Currently Bundled Modules

- `datetime.py` - Date and time types (wrapper around C extension `_datetime`)
- `_strptime.py` - Time parsing implementation for `time.strptime()`
- `calendar.py` - Calendar-related functions

## Finding System Modules

Common locations for Python stdlib modules:

**macOS (Homebrew):**
```
/opt/homebrew/Cellar/python@3.X/3.X.X/Frameworks/Python.framework/Versions/3.X/lib/python3.X/
```

**Linux:**
```
/usr/lib/python3.X/
```

**Find your Python's stdlib location:**
```bash
python3 -c "import sys; print(sys.prefix + '/lib/python' + sys.version[:3])"
```

## Notes

- Only pure Python modules (`.py` files) can be added this way
- C extension modules (`.so`, `.pyd`) are handled differently by componentize-py
- Some modules may have dependencies on other stdlib modules - add those too if needed
- The `__init__.py` file uses `importlib` to dynamically import all modules at build time
