import { anthropicProvider } from "./providers/anthropicProvider.js";
import { openaiProvider } from "./providers/openaiProvider.js";
import type { LLMMessage } from "./providers/types.js";

// Anthropic first, OpenAI as fallback. Falling back mid-stream would mean either
// duplicating or garbling text the client already rendered, so streamText only
// falls through to the next provider if the failing one sent nothing yet.
const providers = [anthropicProvider, openaiProvider];

export async function streamText(
  system: string,
  messages: LLMMessage[],
  onDelta: (text: string) => void
): Promise<string> {
  let lastError: unknown;
  for (const provider of providers) {
    let wroteAny = false;
    try {
      return await provider.streamText(system, messages, (text) => {
        wroteAny = true;
        onDelta(text);
      });
    } catch (error) {
      lastError = error;
      console.error(`[llm] ${provider.name} streamText failed`, error);
      if (wroteAny) {
        throw error;
      }
    }
  }
  throw lastError;
}

export async function createFeedback(system: string, messages: LLMMessage[]): Promise<unknown> {
  let lastError: unknown;
  for (const provider of providers) {
    try {
      return await provider.createFeedback(system, messages);
    } catch (error) {
      lastError = error;
      console.error(`[llm] ${provider.name} createFeedback failed`, error);
    }
  }
  throw lastError;
}
