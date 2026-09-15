import type {
  ExecutionContext,
  NonStreamingProviderLegResult,
  ProviderLegUsage,
  ServerOwnedToolLoopResult,
  ToolCall,
} from "@/lib/skills/toolLoopTypes.ts";
import { executeServerOwned } from "@/lib/skills/interception";
import { runServerOwnedToolLoop, LOOP_BUDGET_MS } from "@/lib/skills/serverOwnedToolLoop.ts";
import { deriveToolRequestIdentity } from "@/lib/skills/stableJson.ts";
import { getIdempotencyKey } from "@/lib/idempotencyLayer";
import { runNonStreamingProviderLeg } from "./nonStreamingProviderLeg.ts";
import type { ProviderLegInput } from "./nonStreamingProviderLeg.ts";
import { shouldRunServerOwnedToolLoop } from "./serverOwnedToolLoopGate.ts";
import { FORMATS } from "../../translator/formats.ts";

export function derivePostInjectionRequestIdentity(input: {
  apiKeyId: string;
  headers: unknown;
  skillRequestId: string;
  postInjectionBody: Record<string, unknown>;
}): string {
  const stableClientRequestId = getIdempotencyKey(input.headers as never);
  // Strip internal helper keys before hashing: the raw client body may carry
  // Map instances (e.g. _toolNameMap) that canonical JSON cannot serialize.
  // These are request-scoped helpers, not identity-relevant content.
  const sanitizedBody = sanitizeBodyForIdentity(input.postInjectionBody);
  return deriveToolRequestIdentity({
    apiKeyId: input.apiKeyId,
    stableClientRequestId,
    skillRequestId: input.skillRequestId,
    postInjectionBody: sanitizedBody,
  });
}

/**
 * Remove internal helper keys and convert Maps/Sets to plain structures so the
 * body can be hashed for request identity. Internal keys (prefixed with _)
 * are request-scoped and must not affect identity.
 */
function sanitizeBodyForIdentity(value: unknown): unknown {
  if (value instanceof Map) {
    const obj: Record<string, unknown> = {};
    for (const [k, v] of value) {
      obj[String(k)] = sanitizeBodyForIdentity(v);
    }
    return obj;
  }
  if (value instanceof Set) {
    return Array.from(value).map(sanitizeBodyForIdentity);
  }
  if (Array.isArray(value)) {
    return value.map(sanitizeBodyForIdentity);
  }
  if (value !== null && typeof value === "object") {
    const proto = Object.getPrototypeOf(value);
    if (proto !== Object.prototype && proto !== null) {
      // Non-plain objects (Date, class instances, etc.) — use string form
      return String(value);
    }
    const result: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      // Skip internal helper keys
      if (k.startsWith("_")) continue;
      result[k] = sanitizeBodyForIdentity(v);
    }
    return result;
  }
  return value;
}

export async function continueServerOwnedToolLoop(input: {
  initialLeg: NonStreamingProviderLegResult & { kind: "ok" };
  sourceBody: Record<string, unknown>;
  sourceFormat: "openai" | "claude";
  skillsModelId: string;
  executionContext: ExecutionContext;
  abortSignal?: AbortSignal;
  deadlineAtMs: number;
  expectedConnectionId?: string;
  followUpLeg: (nextSourceBody: Record<string, unknown>) => Promise<NonStreamingProviderLegResult>;
  executeServerOwned?: (
    calls: ToolCall[],
    context: ExecutionContext
  ) => Promise<import("@/lib/skills/toolLoopTypes.ts").ExecutedToolResult[]>;
}): Promise<ServerOwnedToolLoopResult> {
  const runOwned = input.executeServerOwned ?? executeServerOwned;
  return runServerOwnedToolLoop({
    initialLeg: input.initialLeg,
    sourceBody: input.sourceBody,
    sourceFormat: input.sourceFormat,
    skillsModelId: input.skillsModelId,
    executionContext: input.executionContext,
    abortSignal: input.abortSignal,
    deadlineAtMs: input.deadlineAtMs,
    executeServerOwned: (calls: ToolCall[], context: ExecutionContext) => runOwned(calls, context),
    resumeUpstream: async (nextSourceBody, expectedConnectionId) => {
      if (
        expectedConnectionId &&
        input.expectedConnectionId &&
        expectedConnectionId !== input.expectedConnectionId
      ) {
        return {
          kind: "error",
          result: {
            success: false,
            status: 409,
            response: new Response(null, { status: 409 }),
            error: "Follow-up connection mismatch",
            errorCode: "LEASE_CONNECTION_MISMATCH",
          },
          receipt: input.initialLeg.receipt,
          usage: null,
        };
      }
      return input.followUpLeg(nextSourceBody);
    },
  });
}

export function followUpLegInput(
  base: Omit<
    ProviderLegInput,
    "phase" | "allowAccountRotation" | "allowModelFallback" | "sourceBody"
  >,
  nextSourceBody: Record<string, unknown>,
  expectedConnectionId?: string
): ProviderLegInput {
  return {
    ...base,
    phase: "follow-up",
    sourceBody: nextSourceBody,
    expectedConnectionId,
    allowAccountRotation: false,
    allowModelFallback: false,
  };
}

export function mergeLoopIntoOkLeg(
  leg: NonStreamingProviderLegResult & { kind: "ok" },
  loop: ServerOwnedToolLoopResult
): NonStreamingProviderLegResult & { kind: "ok" } {
  return {
    ...leg,
    response: loop.response ?? leg.response,
    responseForMemoryExtraction:
      loop.responseForMemoryExtraction ?? leg.responseForMemoryExtraction,
    providerBody: loop.finalProviderBody ?? leg.providerBody,
    providerRequest: loop.finalProviderRequest ?? leg.providerRequest,
    usage: loop.cumulativeUsage,
  };
}

export type ToolLoopApplyResult =
  | { kind: "skip" }
  | {
      kind: "ok";
      leg: NonStreamingProviderLegResult & { kind: "ok" };
      usage: ProviderLegUsage | null;
      loop: ServerOwnedToolLoopResult;
    }
  | { kind: "error"; loop: ServerOwnedToolLoopResult };

export async function applyServerOwnedToolLoopIfNeeded(input: {
  enabled: boolean;
  stream: boolean;
  isResponsesEndpoint: boolean;
  sourceFormat: string;
  initialLeg: NonStreamingProviderLegResult;
  sourceBody: Record<string, unknown>;
  skillsModelId: string;
  executionContext: ExecutionContext;
  abortSignal?: AbortSignal;
  expectedConnectionId?: string;
  followUpLeg: (nextSourceBody: Record<string, unknown>) => Promise<NonStreamingProviderLegResult>;
  logReceipt: (receipt: ServerOwnedToolLoopResult["receipts"][number]) => void;
  executeServerOwned?: (
    calls: ToolCall[],
    context: ExecutionContext
  ) => Promise<import("@/lib/skills/toolLoopTypes.ts").ExecutedToolResult[]>;
}): Promise<ToolLoopApplyResult> {
  if (
    input.initialLeg.kind !== "ok" ||
    !shouldRunServerOwnedToolLoop({
      enabled: input.enabled,
      stream: input.stream,
      isResponsesEndpoint: input.isResponsesEndpoint,
      sourceFormat: input.sourceFormat,
    })
  ) {
    return { kind: "skip" };
  }
  const loop = await continueServerOwnedToolLoop({
    initialLeg: input.initialLeg,
    sourceBody: input.sourceBody,
    sourceFormat: input.sourceFormat === FORMATS.CLAUDE ? "claude" : "openai",
    skillsModelId: input.skillsModelId,
    executionContext: input.executionContext,
    abortSignal: input.abortSignal,
    deadlineAtMs: Date.now() + LOOP_BUDGET_MS,
    expectedConnectionId: input.expectedConnectionId,
    followUpLeg: input.followUpLeg,
    executeServerOwned: input.executeServerOwned,
  });
  for (const receipt of loop.receipts) input.logReceipt(receipt);
  if (loop.kind === "error") return { kind: "error", loop };
  return {
    kind: "ok",
    leg: mergeLoopIntoOkLeg(input.initialLeg, loop),
    usage: loop.cumulativeUsage,
    loop,
  };
}

export { LOOP_BUDGET_MS, runNonStreamingProviderLeg };
