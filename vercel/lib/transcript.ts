import type { LLMMessage } from "./providers/types.js";
import type { TranscriptMessage } from "./types.js";

export function toLLMMessages(transcript: TranscriptMessage[]): LLMMessage[] {
  return transcript.map((message) => ({
    role: message.role === "interviewer" ? "assistant" : "user",
    content: message.content
  }));
}

export function nowIso(): string {
  return new Date().toISOString();
}
