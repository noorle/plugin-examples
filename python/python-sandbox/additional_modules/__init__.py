"""
Additional stdlib modules to bundle into WASM.

This package automatically imports all .py files in this directory
to ensure they are bundled by componentize-py.

To add more stdlib modules:
1. Copy the .py file from your system Python to this directory
2. Rebuild with ./build.sh

No need to modify any code - modules are auto-discovered!
"""

import os
import sys
import importlib

# Get the directory containing this __init__.py file
_module_dir = os.path.dirname(__file__)

# Auto-import all .py files in this directory (except __init__.py)
for _filename in os.listdir(_module_dir):
    if _filename.endswith('.py') and _filename != '__init__.py':
        _module_name = _filename[:-3]  # Remove .py extension
        try:
            # Import the module into the global namespace
            # This ensures componentize-py bundles it
            globals()[_module_name] = importlib.import_module(_module_name)
        except Exception as e:
            print(f"Warning: Failed to import {_module_name}: {e}", file=sys.stderr)

# Clean up temporary variables
del _module_dir, _filename, _module_name
