import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const source = readFileSync(
  new URL("../../open-sse/handlers/chatCore.ts", import.meta.url),
  "utf8"
);

// The rotation loop moved to providerExecutionPipeline.ts — the source guard
// must inspect the module that actually owns the loop.
const pipelineSource = readFileSync(
  new URL("../../open-sse/handlers/chatCore/providerExecutionPipeline.ts", import.meta.url),
  "utf8"
);

test("chatCore acquires cumulative gates immediately before withRateLimit", () => {
  const acquire = source.indexOf("await acquireConcurrencyGates(");
  const rateLimit = source.indexOf("await withRateLimit(", acquire);
  assert.ok(acquire >= 0, "hierarchical admission must be present");
  assert.ok(rateLimit > acquire, "hierarchical admission must precede withRateLimit");

  const admission = source.slice(acquire, rateLimit);
  assert.match(admission, /key: "global"/);
  assert.match(admission, /key: `provider:\$\{canonicalProviderKey\}`/);
  assert.match(admission, /key: accountSemaphoreKey/);
  assert.match(admission, /globalConcurrentRequests/);
  assert.match(admission, /providerConcurrency/);
  assert.match(admission, /maxWaitMs/);
  assert.match(admission, /maxQueueDepth/);
});

test("rotation loop retries on rotation/refresh/fallback signals", () => {
  // The per-attempt rotation loop lives in providerExecutionPipeline.ts. It
  // must retry when any of the rotation signals is set: antigravity BYOP
  // rotation, auth refresh, or model fallback.
  const loopStart = pipelineSource.indexOf("while (");
  assert.ok(loopStart >= 0, "rotation loop must exist");
  const loopHeader = pipelineSource.slice(loopStart, pipelineSource.indexOf("{", loopStart));
  assert.match(loopHeader, /attempts < maxAttempts/);
  assert.match(loopHeader, /antigravityByopRotationPending/);
  assert.match(loopHeader, /authRefreshPending/);
  assert.match(loopHeader, /modelFallbackPending/);
});
