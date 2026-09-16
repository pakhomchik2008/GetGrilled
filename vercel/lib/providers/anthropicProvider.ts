import type Anthropic from "@anthropic-ai/sdk";
import { MAX_TOKENS, MODEL, anthropic } from "../anthropic.js";
import type { LLMMessage, LLMProvider, ToolDefinition } from "./types.js";

function toAnthropicMessages(messages: LLMMessage[]): Anthropic.MessageParam[] {
  return messages.map((message) => ({
    role: message.role,
    content:
      typeof message.content === "string"
        ? message.content
        : message.content.map((part) =>
            part.type === "text"
              ? { type: "text" as const, text: part.text }
              : {
                  type: "image" as const,
                  source: { type: "base64" as const, media_type: part.mediaType, data: part.base64 }
                }
          )
  }));
}

export const anthropicProvider: LLMProvider = {
  name: "anthropic",

  async streamText(system, messages, onDelta) {
    const stream = anthropic.messages.stream({
      model: MODEL,
      max_tokens: MAX_TOKENS,
      system,
      messages: toAnthropicMessages(messages)
    });
    stream.on("text", onDelta);
    const finalMessage = await stream.finalMessage();
    return finalMessage.content
      .filter((block): block is Anthropic.TextBlock => block.type === "text")
      .map((block) => block.text)
      .join("");
  },

  async callTool(system, messages, tool: ToolDefinition) {
    const response = await anthropic.messages.create({
      model: MODEL,
      max_tokens: MAX_TOKENS,
      system,
      messages: toAnthropicMessages(messages),
      tools: [tool],
      tool_choice: { type: "tool", name: tool.name }
    });
    const toolUse = response.content.find(
      (block): block is Anthropic.ToolUseBlock => block.type === "tool_use" && block.name === tool.name
    );
    if (!toolUse) {
      throw new Error(`Anthropic did not return a ${tool.name} tool call`);
    }
    return toolUse.input;
  }
};
