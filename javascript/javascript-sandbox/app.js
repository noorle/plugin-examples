/**
 * JavaScript Sandbox Plugin for Noorle
 *
 * This plugin provides a sandboxed JavaScript execution environment that can:
 * - Execute arbitrary JavaScript statements (execCode)
 * - Evaluate JavaScript expressions (evalExpr)
 * - Access filesystem within preopened directories (Node.js fs API compatible)
 */

// Import WASI filesystem interfaces
import { Descriptor, DirectoryEntryStream } from 'wasi:filesystem/types@0.2.7';
import { getDirectories } from 'wasi:filesystem/preopens@0.2.7';

// WASI Filesystem flag helpers (Component Model uses objects with boolean properties)
const PathFlags = {
  SYMLINK_FOLLOW: { symlinkFollow: true }
};

const OpenFlags = {
  CREATE: { create: true },
  DIRECTORY: { directory: true },
  EXCLUSIVE: { exclusive: true },
  TRUNC: { truncate: true }
};

const DescriptorFlags = {
  READ: { read: true },
  WRITE: { write: true },
  FILE_INTEGRITY_SYNC: { fileIntegritySync: true },
  DATA_INTEGRITY_SYNC: { dataIntegritySync: true },
  REQUESTED_WRITE_SYNC: { requestedWriteSync: true },
  MUTATE_DIRECTORY: { mutateDirectory: true }
};

// Helper to combine flags
function combineFlags(...flags) {
  return Object.assign({}, ...flags);
}

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
 * Dirent class - represents a directory entry (like Node.js fs.Dirent)
 */
class Dirent {
  constructor(name, type) {
    this.name = name;
    this._type = type;
  }

  isFile() {
    return this._type === 'regular-file';
  }

  isDirectory() {
    return this._type === 'directory';
  }

  isSymbolicLink() {
    return this._type === 'symbolic-link';
  }

  isBlockDevice() {
    return this._type === 'block-device';
  }

  isCharacterDevice() {
    return this._type === 'character-device';
  }

  isFIFO() {
    return this._type === 'fifo';
  }

  isSocket() {
    return this._type === 'socket';
  }
}

/**
 * Stats class - file/directory statistics (simplified Node.js fs.Stats)
 */
class Stats {
  constructor(stat) {
    this.size = Number(stat.size);
    this._type = stat.type;
    this.mode = 0; // Could be expanded
    this.nlink = Number(stat.linkCount || 0);

    // Timestamps (if available)
    if (stat.dataModificationTimestamp) {
      this.mtimeMs = Number(stat.dataModificationTimestamp.seconds) * 1000;
      this.mtime = new Date(this.mtimeMs);
    }
    if (stat.dataAccessTimestamp) {
      this.atimeMs = Number(stat.dataAccessTimestamp.seconds) * 1000;
      this.atime = new Date(this.atimeMs);
    }
    if (stat.statusChangeTimestamp) {
      this.ctimeMs = Number(stat.statusChangeTimestamp.seconds) * 1000;
      this.ctime = new Date(this.ctimeMs);
    }
  }

  isFile() {
    return this._type === 'regular-file';
  }

  isDirectory() {
    return this._type === 'directory';
  }

  isSymbolicLink() {
    return this._type === 'symbolic-link';
  }

  isBlockDevice() {
    return this._type === 'block-device';
  }

  isCharacterDevice() {
    return this._type === 'character-device';
  }

  isFIFO() {
    return this._type === 'fifo';
  }

  isSocket() {
    return this._type === 'socket';
  }
}

/**
 * FileSystem API - Node.js fs module compatible (synchronous operations)
 */
class FileSystem {
  constructor() {
    const dirs = getDirectories();
    if (!dirs || dirs.length === 0) {
      throw new Error("No preopened directories available");
    }
    // dirs is an array of tuples: [[descriptor, path], ...]
    // Store all preopened directories as a map: path -> descriptor
    this.preopens = new Map();
    for (const [descriptor, path] of dirs) {
      this.preopens.set(path, descriptor);
    }

    // Use first directory as default
    this.rootDir = dirs[0][0];
  }

  /**
   * Get the correct descriptor for a path
   * Handles absolute paths by matching against preopened directories
   */
  _getDescriptorForPath(path) {
    // Handle absolute paths - find matching preopen
    if (path.startsWith('/')) {
      // Find the preopened directory that matches this path
      for (const [preopenPath, descriptor] of this.preopens) {
        if (path === preopenPath || path.startsWith(preopenPath + '/')) {
          // Return descriptor and the relative path within that preopen
          const relativePath = path === preopenPath ? '.' : path.slice(preopenPath.length + 1);
          return { descriptor, path: relativePath };
        }
      }
      // No matching preopen found - try to use as relative path from rootDir
      // This handles cases like /file.txt when / is preopened
      if (this.preopens.has('/')) {
        return { descriptor: this.preopens.get('/'), path: path.slice(1) };
      }
      // Fallback: treat as relative to rootDir
      return { descriptor: this.rootDir, path: path };
    }

    // Relative path - use rootDir
    return { descriptor: this.rootDir, path: path };
  }

  /**
   * Synchronously read entire file contents
   * @param {string} path - File path
   * @param {string|object} [options='utf8'] - Encoding or options object
   * @returns {string|Buffer} File contents
   */
  readFileSync(path, options = 'utf8') {
    const encoding = typeof options === 'string' ? options : (options?.encoding || 'utf8');

    const { descriptor, path: relativePath } = this._getDescriptorForPath(path);

    let file;
    try {
      // Component Model might throw instead of returning {tag, val}
      file = descriptor.openAt(
        PathFlags.SYMLINK_FOLLOW,
        relativePath,
        {}, // No open flags (read existing file)
        DescriptorFlags.READ
      );
    } catch (e) {
      const err = new Error(`ENOENT: no such file or directory, open '${path}'`);
      err.code = 'ENOENT';
      err.path = path;
      err.errno = -2;
      throw err;
    }
    let offset = 0n;
    const chunks = [];

    try {
      while (true) {
        let result;
        try {
          result = file.read(65536n, offset); // 64KB chunks
        } catch (e) {
          throw new Error(`EIO: i/o error, read`);
        }

        // Result might be [bytes, eof] tuple directly or {val: [bytes, eof]}
        const [bytes, eof] = Array.isArray(result) ? result : result.val;

        if (bytes.length > 0) {
          chunks.push(bytes);
          offset += BigInt(bytes.length);
        }

        if (eof) break;
      }
    } finally {
      // Resource cleanup handled automatically
    }

    const totalLength = chunks.reduce((sum, chunk) => sum + chunk.length, 0);
    const allBytes = new Uint8Array(totalLength);
    let position = 0;
    for (const chunk of chunks) {
      allBytes.set(chunk, position);
      position += chunk.length;
    }

    if (encoding === 'utf8' || encoding === 'utf-8') {
      return new TextDecoder().decode(allBytes);
    } else if (encoding === null || encoding === 'buffer') {
      return allBytes;
    }

    return new TextDecoder().decode(allBytes);
  }

  /**
   * Synchronously write data to file
   * @param {string} path - File path
   * @param {string|Uint8Array} data - Data to write
   * @param {string|object} [options='utf8'] - Encoding or options object
   */
  writeFileSync(path, data, options = 'utf8') {
    const encoding = typeof options === 'string' ? options : (options?.encoding || 'utf8');

    const { descriptor, path: relativePath } = this._getDescriptorForPath(path);

    let file;
    try {
      file = descriptor.openAt(
        PathFlags.SYMLINK_FOLLOW,
        relativePath,
        combineFlags(OpenFlags.CREATE, OpenFlags.TRUNC),
        combineFlags(DescriptorFlags.WRITE, DescriptorFlags.READ)
      );
    } catch (e) {
      const err = new Error(`EACCES: permission denied, open '${path}'`);
      err.code = 'EACCES';
      err.path = path;
      err.errno = -13;
      throw err;
    }

    try {
      let bytes;
      if (typeof data === 'string') {
        bytes = new TextEncoder().encode(data);
      } else {
        bytes = data;
      }

      try {
        file.write(bytes, 0n);
      } catch (e) {
        throw new Error(`EIO: i/o error, write`);
      }
    } finally {
      // Resource cleanup handled automatically
    }
  }

  /**
   * Synchronously append data to file
   * @param {string} path - File path
   * @param {string|Uint8Array} data - Data to append
   * @param {string|object} [options='utf8'] - Encoding or options object
   */
  appendFileSync(path, data, options = 'utf8') {
    let existingContent = '';
    try {
      existingContent = this.readFileSync(path, options);
    } catch (e) {
      if (e.code !== 'ENOENT') throw e;
      // File doesn't exist, that's okay for append
    }

    const newContent = typeof data === 'string' ? existingContent + data : existingContent;
    this.writeFileSync(path, newContent, options);
  }

  /**
   * Synchronously test if path exists
   * @param {string} path - Path to check
   * @returns {boolean}
   */
  existsSync(path) {
    try {
      const { descriptor, path: relativePath } = this._getDescriptorForPath(path);
      descriptor.statAt(
        PathFlags.SYMLINK_FOLLOW,
        relativePath
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /**
   * Synchronously read directory contents
   * @param {string} path - Directory path
   * @param {object|string} [options] - Options object or encoding
   * @param {boolean} [options.withFileTypes=false] - Return Dirent objects
   * @param {string} [options.encoding='utf8'] - Encoding for names
   * @returns {Array<string>|Array<Dirent>}
   */
  readdirSync(path = '.', options = {}) {
    const withFileTypes = typeof options === 'object' ? (options?.withFileTypes || false) : false;

    const { descriptor, path: relativePath } = this._getDescriptorForPath(path);
    let targetDir;

    if (relativePath === '.' || relativePath === '') {
      targetDir = descriptor;
    } else {
      try {
        targetDir = descriptor.openAt(
          PathFlags.SYMLINK_FOLLOW,
          relativePath,
          OpenFlags.DIRECTORY,
          DescriptorFlags.READ
        );
      } catch (e) {
        const err = new Error(`ENOENT: no such file or directory, scandir '${path}'`);
        err.code = 'ENOENT';
        err.path = path;
        err.errno = -2;
        throw err;
      }
    }

    let stream;
    try {
      stream = targetDir.readDirectory();
    } catch (e) {
      const err = new Error(`ENOTDIR: not a directory, scandir '${path}'`);
      err.code = 'ENOTDIR';
      err.path = path;
      throw err;
    }

    const entries = [];

    try {
      while (true) {
        let entry;
        try {
          entry = stream.readDirectoryEntry();
        } catch (e) {
          break;
        }

        if (!entry) break;

        if (withFileTypes) {
          entries.push(new Dirent(entry.name, entry.type));
        } else {
          entries.push(entry.name);
        }
      }
    } finally {
      // Resource cleanup handled automatically
    }

    return entries;
  }

  /**
   * Synchronously delete a file
   * @param {string} path - File path
   */
  unlinkSync(path) {
    const { descriptor, path: relativePath } = this._getDescriptorForPath(path);
    try {
      descriptor.unlinkFileAt(relativePath);
    } catch (e) {
      const err = new Error(`ENOENT: no such file or directory, unlink '${path}'`);
      err.code = 'ENOENT';
      err.path = path;
      err.errno = -2;
      throw err;
    }
  }

  /**
   * Synchronously create a directory
   * @param {string} path - Directory path
   * @param {object|number} [options] - Options object or mode
   * @param {boolean} [options.recursive=false] - Create parent directories
   */
  mkdirSync(path, options = {}) {
    const recursive = typeof options === 'object' ? (options?.recursive || false) : false;

    if (recursive) {
      // For absolute paths like /working/a/b/c, we need to handle the preopen prefix
      const { descriptor, path: relativePath } = this._getDescriptorForPath(path);

      const parts = relativePath.split('/').filter(p => p && p !== '.');
      let currentPath = '';

      for (const part of parts) {
        currentPath += (currentPath ? '/' : '') + part;

        if (!this.existsSync(path.startsWith('/') ?
          path.substring(0, path.lastIndexOf('/') + 1) + currentPath : currentPath)) {
          try {
            descriptor.createDirectoryAt(currentPath);
          } catch (e) {
            const err = new Error(`EACCES: permission denied, mkdir '${currentPath}'`);
            err.code = 'EACCES';
            err.path = currentPath;
            throw err;
          }
        }
      }
      return;
    }

    const { descriptor, path: relativePath } = this._getDescriptorForPath(path);
    try {
      descriptor.createDirectoryAt(relativePath);
    } catch (e) {
      const err = new Error(`EEXIST: file already exists, mkdir '${path}'`);
      err.code = 'EEXIST';
      err.path = path;
      err.errno = -17;
      throw err;
    }
  }

  /**
   * Synchronously remove a directory
   * @param {string} path - Directory path
   * @param {object} [options] - Options object
   * @param {boolean} [options.recursive=false] - Remove recursively
   */
  rmdirSync(path, options = {}) {
    const { descriptor, path: relativePath } = this._getDescriptorForPath(path);
    try {
      descriptor.removeDirectoryAt(relativePath);
    } catch (e) {
      const err = new Error(`ENOENT: no such file or directory, rmdir '${path}'`);
      err.code = 'ENOENT';
      err.path = path;
      err.errno = -2;
      throw err;
    }
  }

  /**
   * Synchronously remove files or directories (recursively)
   * @param {string} path - Path to remove
   * @param {object} [options] - Options object
   * @param {boolean} [options.recursive=false] - Remove recursively
   * @param {boolean} [options.force=false] - Ignore errors
   */
  rmSync(path, options = {}) {
    const recursive = options?.recursive || false;
    const force = options?.force || false;

    try {
      const stat = this.statSync(path);

      if (stat.isDirectory()) {
        if (recursive) {
          // Read directory contents and remove recursively
          const entries = this.readdirSync(path);
          for (const entry of entries) {
            const entryPath = `${path}/${entry}`;
            this.rmSync(entryPath, options);
          }
        }
        this.rmdirSync(path);
      } else {
        this.unlinkSync(path);
      }
    } catch (e) {
      if (!force) throw e;
    }
  }

  /**
   * Synchronously get file/directory stats
   * @param {string} path - Path to stat
   * @param {object} [options] - Options object
   * @returns {Stats}
   */
  statSync(path, options = {}) {
    const { descriptor, path: relativePath } = this._getDescriptorForPath(path);
    let stat;
    try {
      stat = descriptor.statAt(
        PathFlags.SYMLINK_FOLLOW,
        relativePath
      );
    } catch (e) {
      const err = new Error(`ENOENT: no such file or directory, stat '${path}'`);
      err.code = 'ENOENT';
      err.path = path;
      err.errno = -2;
      throw err;
    }

    return new Stats(stat);
  }

  /**
   * Synchronously get file/directory stats (don't follow symlinks)
   * @param {string} path - Path to stat
   * @param {object} [options] - Options object
   * @returns {Stats}
   */
  lstatSync(path, options = {}) {
    const { descriptor, path: relativePath } = this._getDescriptorForPath(path);
    let stat;
    try {
      stat = descriptor.statAt(
        {}, // Don't follow symlinks (empty flags)
        relativePath
      );
    } catch (e) {
      const err = new Error(`ENOENT: no such file or directory, lstat '${path}'`);
      err.code = 'ENOENT';
      err.path = path;
      err.errno = -2;
      throw err;
    }

    return new Stats(stat);
  }

  /**
   * Synchronously rename/move a file or directory
   * @param {string} oldPath - Current path
   * @param {string} newPath - New path
   */
  renameSync(oldPath, newPath) {
    // WASI filesystem doesn't have a direct rename at root level
    // This is a limitation - would need to implement via read/write/delete
    throw new Error('renameSync is not supported in this WASI environment');
  }

  /**
   * Synchronously copy a file
   * @param {string} src - Source path
   * @param {string} dest - Destination path
   * @param {number} [flags=0] - Copy flags
   */
  copyFileSync(src, dest, flags = 0) {
    const content = this.readFileSync(src, null); // Read as buffer
    this.writeFileSync(dest, content, null);
  }
}

// Create and expose filesystem API globally (lazy initialization)
let fsInstance = null;
let fsInitialized = false;

function getFs() {
  if (!fsInitialized) {
    fsInitialized = true;
    try {
      fsInstance = new FileSystem();
    } catch (e) {
      // If no preopened directories, fs will be null
      fsInstance = null;
    }
  }
  return fsInstance;
}

// Make fs available globally for user code (Node.js style)
// Use a getter so it's lazily initialized at first access
Object.defineProperty(globalThis, 'fs', {
  get: getFs,
  enumerable: true,
  configurable: false
});

/**
 * Evaluate a JavaScript expression and return the result as JSON.
 *
 * This function evaluates a single JavaScript expression and serializes
 * the result to JSON format. Useful for calculations and data transformations.
 *
 * @param {string} expression - JavaScript expression to evaluate
 * @returns {string} JSON-serialized result
 * @throws {Error} If evaluation fails
 *
 * @example
 * evalExpr("2 + 2") // Returns "4"
 * evalExpr("fs.readdirSync('.')") // Returns list of files
 */
export function evalExpr(expression) {
  try {
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
 * @param {string} statements - JavaScript code to execute
 * @returns {string} Captured console output
 * @throws {Error} If execution fails
 *
 * @example
 * execCode("console.log('Hello')") // Returns "Hello\n"
 * execCode("const files = fs.readdirSync('.'); console.log(files)") // Lists files
 */
export function execCode(statements) {
  const capture = new ConsoleCapture();
  try {
    const fn = Function('console', `"use strict"; ${statements}`);
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
