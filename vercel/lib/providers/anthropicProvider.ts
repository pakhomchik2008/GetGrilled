import type Anthropic from "@anthropic-ai/sdk";
import { MAX_TOKENS, MODEL, anthropic } from "../anthropic.js";
import type { LLMProvider, ToolDefinition } from "./types.js";

export const anthropicProvider: LLMProvider = {
  name: "anthropic",

  async streamText(system, messages, onDelta) {
    const stream = anthropic.messages.stream({
      model: MODEL,
      max_tokens: MAX_TOKENS,
      system,
      messages: messages as Anthropic.MessageParam[]
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
      messages: messages as Anthropic.MessageParam[],
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
