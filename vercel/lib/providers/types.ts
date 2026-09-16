export interface LLMMessage {
  role: "user" | "assistant";
  content: string;
}

export interface ToolDefinition {
  name: string;
  description: string;
  input_schema: {
    type: "object";
    required: string[];
    properties: Record<string, unknown>;
  };
}

export interface LLMProvider {
  name: string;
  // Streams the reply, invoking onDelta per text chunk, and returns the full text.
  streamText(system: string, messages: LLMMessage[], onDelta: (text: string) => void): Promise<string>;
  // Forces a call to `tool` and returns its raw (unvalidated) arguments.
  callTool(system: string, messages: LLMMessage[], tool: ToolDefinition): Promise<unknown>;
}
