import type { LLMMessage } from "./providers/types.js";
import type { TranscriptMessage } from "./types.js";

export function toLLMMessages(transcript: TranscriptMessage[]): LLMMessage[] {
  return transcript.map((message) => ({
    role: message.role === "interviewer" ? "assistant" : "user",
    content: message.image
      ? [
          ...(message.content ? [{ type: "text" as const, text: message.content }] : []),
          { type: "image" as const, mediaType: message.image.mediaType, base64: message.image.base64 }
        ]
      : message.content
  }));
}

export function nowIso(): string {
  return new Date().toISOString();
}
