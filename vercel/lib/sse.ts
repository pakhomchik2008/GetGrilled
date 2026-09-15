import type { VercelResponse } from "@vercel/node";
import type Anthropic from "@anthropic-ai/sdk";
import { MAX_TOKENS, MODEL, anthropic } from "./anthropic.js";

export function startSSE(res: VercelResponse): void {
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  res.flushHeaders?.();
}

function writeEvent(res: VercelResponse, payload: unknown): void {
  res.write(`data: ${JSON.stringify(payload)}\n\n`);
}

/// Streams a Claude response as SSE `delta` events, then returns the full assistant text.
/// Does not write the terminal `done` event — callers do that after persisting state,
/// so the client only learns a turn is "done" once it is safely saved.
export async function streamAssistantText(
  res: VercelResponse,
  system: string,
  messages: Anthropic.MessageParam[]
): Promise<string> {
  const stream = anthropic.messages.stream({
    model: MODEL,
    max_tokens: MAX_TOKENS,
    system,
    messages
  });
  stream.on("text", (text) => writeEvent(res, { type: "delta", text }));
  const finalMessage = await stream.finalMessage();
  return finalMessage.content
    .filter((block): block is Anthropic.TextBlock => block.type === "text")
    .map((block) => block.text)
    .join("");
}

export function writeDone(res: VercelResponse, sessionId: string): void {
  writeEvent(res, { type: "done", sessionId });
  res.end();
}
