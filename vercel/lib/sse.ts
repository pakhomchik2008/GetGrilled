import type { VercelResponse } from "@vercel/node";
import { streamText } from "./llmClient.js";
import type { LLMMessage } from "./providers/types.js";

export function startSSE(res: VercelResponse): void {
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  res.flushHeaders?.();
}

function writeEvent(res: VercelResponse, payload: unknown): void {
  res.write(`data: ${JSON.stringify(payload)}\n\n`);
}

// Streams the interviewer's reply as SSE `delta` events, then returns the full text.
// Does not write the terminal `done` event — callers do that after persisting state,
// so the client only learns a turn is "done" once it is safely saved.
export async function streamAssistantText(res: VercelResponse, system: string, messages: LLMMessage[]): Promise<string> {
  return streamText(system, messages, (text) => writeEvent(res, { type: "delta", text }));
}

export function writeDone(res: VercelResponse, sessionId: string, extra?: Record<string, unknown>): void {
  writeEvent(res, { type: "done", sessionId, ...extra });
  res.end();
}
