// Type declarations for WASI imports
// These are NOT auto-generated - add type definitions for any WASI interfaces you use

// WASI environment module
declare module "wasi:cli/environment@0.2.7" {
  export function getEnvironment(): Array<[string, string]>;
}

// Fetch API (available in ComponentizeJS/StarlingMonkey)
declare global {
  function fetch(url: string, options?: RequestInit): Promise<Response>;

  interface RequestInit {
    method?: string;
    headers?: Record<string, string> | Headers;
    body?: string | Blob | ArrayBuffer | FormData | URLSearchParams;
    mode?: string;
    credentials?: string;
    cache?: string;
    redirect?: string;
    referrer?: string;
    integrity?: string;
  }

  interface Response {
    ok: boolean;
    status: number;
    statusText: string;
    headers: Headers;
    url: string;
    json(): Promise<any>;
    text(): Promise<string>;
    arrayBuffer(): Promise<ArrayBuffer>;
    blob(): Promise<Blob>;
  }

  interface Headers {
    append(name: string, value: string): void;
    delete(name: string): void;
    get(name: string): string | null;
    has(name: string): boolean;
    set(name: string, value: string): void;
  }
}

