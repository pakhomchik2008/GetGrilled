export interface LLMMessage {
  role: "user" | "assistant";
  content: string;
}

export interface LLMProvider {
  name: string;
  // Streams the reply, invoking onDelta per text chunk, and returns the full text.
  streamText(system: string, messages: LLMMessage[], onDelta: (text: string) => void): Promise<string>;
  // Returns the raw (unvalidated) submit_feedback tool/function-call arguments.
  createFeedback(system: string, messages: LLMMessage[]): Promise<unknown>;
}
