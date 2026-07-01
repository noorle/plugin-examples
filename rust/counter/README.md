# Counter Plugin (Rust) - Noorle Example

A minimal Rust plugin demonstrating `wasi:keyvalue/store` — the WASI-standard
interface for per-session persistent state in Noorle plugins.

## What it does

Exports one function, `increment(name: string) -> result<u32, string>`, that
increments and returns a named counter. The counter persists across calls
within the same session (backed by the host's per-session key-value store)
and is independent per `name`, so a single session can track several
counters (e.g. `"requests"`, `"errors"`) without them colliding.

## Why this example exists

Most examples in this repo show request/response plugins with no memory
between calls. This one shows the other half: a plugin that needs to
remember something across invocations — a running total, a cache, a
rate-limit counter — without standing up external storage.

## WIT

```wit
world counter-component {
    import wasi:keyvalue/store@0.2.0-draft;
    export increment: func(name: string) -> result<u32, string>;
}
```

`wit/deps/wasi-keyvalue-0.2.0-draft/` was vendored with `wkg wit fetch`, the
same tool used for every other WIT dependency in this repo.

## Build

```bash
./build.sh
```

Produces `dist/plugin.wasm`, same as every other example here.
