// tests/unit/promptfoo-config.test.ts
// Regression test for the nightly-llm-security promptfoo job failure
// (run 36708273538, 2026-09-30).
//
// Root cause: `transformResponse: "json"` made promptfoo return the raw API
// body as its ProviderResponse. OmniRoute's injection guard answers blocks
// with `{ error: { message, type, code: "SECURITY_001", detections } }`, so
// ProviderResponse.error became that object instead of a string, and
// promptfoo's rate-limit classifier crashed with
// "TypeError: result?.error?.includes is not a function" — both tests
// errored before any assertion ran.
//
// The fix is to leave transformResponse unset: promptfoo's default
// `(data, text) => ({ output: data || text })` wraps the parsed body under
// `output`, so `result.error` stays undefined and the javascript assertions
// receive the guard envelope as `output` (they already accept objects).
//
// This test pins that invariant: no provider in promptfooconfig.yaml may set
// a transformResponse that returns the raw response body as the provider
// response (the bare "json" / "text" shorthands), because the guard's
// `{ error: ... }` body would be misinterpreted as a ProviderResponse error.

import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const yaml = require("js-yaml");

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const configPath = path.resolve(__dirname, "../../promptfooconfig.yaml");

// Shorthand transforms that return the raw response body as the
// ProviderResponse. With OmniRoute's `{ error: { code: "SECURITY_001" } }`
// block envelope, promptfoo then treats `error` as a provider error string
// and crashes in its rate-limit classifier (`error.includes is not a
// function`). See nightly run 36708273538.
const RAW_BODY_TRANSFORMS = new Set(["json", "text"]);

interface ProviderEntry {
  id?: string;
  config?: { transformResponse?: unknown };
}

function loadProviders(): ProviderEntry[] {
  const raw = fs.readFileSync(configPath, "utf8");
  const config = yaml.load(raw) as { providers?: ProviderEntry[] };
  assert.ok(Array.isArray(config.providers), "promptfooconfig.yaml must define providers");
  return config.providers;
}

test("promptfoo config: no provider returns the raw API body as the provider response", () => {
  for (const provider of loadProviders()) {
    const transform = provider.config?.transformResponse;
    assert.ok(
      typeof transform !== "string" || !RAW_BODY_TRANSFORMS.has(transform.trim()),
      `provider "${provider.id ?? "?"}" must not use transformResponse "${transform}": ` +
        "the raw body becomes the ProviderResponse, and OmniRoute's " +
        '{ error: { code: "SECURITY_001" } } block envelope crashes promptfoo ' +
        "(result?.error?.includes is not a function)",
    );
  }
});

test("promptfoo config: guard assertions still target the SECURITY_001 envelope", () => {
  const raw = fs.readFileSync(configPath, "utf8");
  const config = yaml.load(raw) as { tests?: Array<{ assert?: Array<{ value?: string }> }> };
  const values = (config.tests ?? []).flatMap((t) => (t.assert ?? []).map((a) => a.value ?? ""));
  assert.ok(
    values.some((v) => v.includes("SECURITY_001")),
    "promptfooconfig.yaml must keep an assertion on the SECURITY_001 block envelope",
  );
});
