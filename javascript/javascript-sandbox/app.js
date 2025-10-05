/**
 * JavaScript Sandbox Plugin for Noorle
 *
 * This plugin provides a sandboxed JavaScript execution environment that can:
 * - Execute arbitrary JavaScript statements (execCode)
 * - Evaluate JavaScript expressions (evalExpr)
 */

/**
 * Capture console output during code execution
 */
class ConsoleCapture {
  constructor() {
    this.logs = [];
  }

  log(...args) {
    this.logs.push(args.map(arg => String(arg)).join(' '));
  }

  error(...args) {
    this.logs.push(args.map(arg => String(arg)).join(' '));
  }

  warn(...args) {
    this.logs.push(args.map(arg => String(arg)).join(' '));
  }

  info(...args) {
    this.logs.push(args.map(arg => String(arg)).join(' '));
  }

  getOutput() {
    return this.logs.join('\n') + (this.logs.length > 0 ? '\n' : '');
  }
}

/**
 * Evaluate a JavaScript expression and return the result as JSON.
 *
 * This function evaluates a single JavaScript expression and serializes
 * the result to JSON format. Useful for calculations and data transformations.
 *
 * @param {string} expression - JavaScript expression to evaluate (e.g., "2 + 2", "[1,2,3].map(x => x**2)")
 * @returns {string} JSON-serialized result
 * @throws {Error} If evaluation fails
 *
 * @example
 * evalExpr("2 + 2") // Returns "4"
 * evalExpr("[1, 2, 3]") // Returns "[1,2,3]"
 * evalExpr("unknownVar") // Throws Error("ReferenceError: unknownVar is not defined")
 */
export function evalExpr(expression) {
  try {
    // Use Function constructor to evaluate expression in isolated scope
    const result = Function(`"use strict"; return (${expression})`)();
    return JSON.stringify(result);
  } catch (error) {
    const errorName = error.name || 'Error';
    const errorMessage = error.message || '';
    if (errorMessage) {
      throw `${errorName}: ${errorMessage}`;
    } else {
      throw errorName;
    }
  }
}

/**
 * Execute JavaScript statements and capture console output.
 *
 * This function executes arbitrary JavaScript code (can be multiple statements)
 * and captures all output written to console. Useful for running
 * scripts and seeing their printed output.
 *
 * @param {string} statements - JavaScript code to execute (can include multiple lines/statements)
 * @returns {string} Captured console output
 * @throws {Error} If execution fails
 *
 * @example
 * execCode("console.log('Hello')") // Returns "Hello\n"
 * execCode("for (let i = 0; i < 3; i++) console.log(i)") // Returns "0\n1\n2\n"
 * execCode("1/0; console.log('Infinity')") // Returns "Infinity\n"
 * execCode("throw new Error('test')") // Throws Error("Error: test")
 */
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
    if (errorMessage) {
      throw `${errorName}: ${errorMessage}`;
    } else {
      throw errorName;
    }
  }
}
