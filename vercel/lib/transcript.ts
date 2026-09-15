import type Anthropic from "@anthropic-ai/sdk";
import type { TranscriptMessage } from "./types.js";

export function toClaudeMessages(transcript: TranscriptMessage[]): Anthropic.MessageParam[] {
  return transcript.map((message) => ({
    role: message.role === "interviewer" ? "assistant" : "user",
    content: message.content
  }));
}

export function nowIso(): string {
  return new Date().toISOString();
}
