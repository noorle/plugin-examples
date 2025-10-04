"""
Python Sandbox Plugin for Noorle

This plugin provides a sandboxed Python execution environment that can:
- Execute arbitrary Python statements (exec)
- Evaluate Python expressions (eval)

Inspired by componentize-py sandbox example.
"""

import contextlib
import io
import json
import wit_world
from wit_world.types import Err


def handle_exception(e: Exception) -> Err[str]:
    """
    Convert a Python exception to an Err result with a formatted error message.

    Args:
        e: The exception to convert

    Returns:
        Err result with the exception type and message
    """
    message = str(e)
    if message == "":
        return Err(f"{type(e).__name__}")
    else:
        return Err(f"{type(e).__name__}: {message}")


class WitWorld(wit_world.WitWorld):
    """
    Python Sandbox component that implements code execution capabilities.
    """

    def eval(self, expression: str) -> str:
        """
        Evaluate a Python expression and return the result as JSON.

        This function evaluates a single Python expression and serializes
        the result to JSON format. Useful for calculations and data transformations.

        Args:
            expression: Python expression to evaluate (e.g., "2 + 2", "[x**2 for x in range(5)]")

        Returns:
            JSON-serialized result

        Raises:
            Err with error message if evaluation fails

        Examples:
            eval("2 + 2") -> "4"
            eval("[1, 2, 3]") -> "[1, 2, 3]"
            eval("unknown_var") -> raises Err("NameError: name 'unknown_var' is not defined")
        """
        try:
            result = eval(expression)
            return json.dumps(result)
        except Exception as e:
            raise handle_exception(e)

    def exec(self, statements: str) -> str:
        """
        Execute Python statements and capture stdout/stderr output.

        This function executes arbitrary Python code (can be multiple statements)
        and captures all output written to stdout and stderr. Useful for running
        scripts and seeing their printed output.

        Args:
            statements: Python code to execute (can include multiple lines/statements)

        Returns:
            Captured output as string

        Raises:
            Err with error message if execution fails

        Examples:
            exec("print('Hello')") -> "Hello\n"
            exec("for i in range(3):\n    print(i)") -> "0\n1\n2\n"
            exec("1/0") -> raises Err("ZeroDivisionError: division by zero")
        """
        buffer = io.StringIO()
        try:
            # Redirect stdout and stderr to our buffer
            with contextlib.redirect_stdout(buffer), contextlib.redirect_stderr(buffer):
                exec(statements)
            return buffer.getvalue()
        except Exception as e:
            raise handle_exception(e)
