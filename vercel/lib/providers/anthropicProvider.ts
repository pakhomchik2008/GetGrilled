import type Anthropic from "@anthropic-ai/sdk";
import { FEEDBACK_TOOL, MAX_TOKENS, MODEL, anthropic } from "../anthropic.js";
import type { LLMProvider } from "./types.js";

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

  async createFeedback(system, messages) {
    const response = await anthropic.messages.create({
      model: MODEL,
      max_tokens: MAX_TOKENS,
      system,
      messages: messages as Anthropic.MessageParam[],
      tools: [FEEDBACK_TOOL],
      tool_choice: { type: "tool", name: "submit_feedback" }
    });
    const toolUse = response.content.find(
      (block): block is Anthropic.ToolUseBlock => block.type === "tool_use" && block.name === "submit_feedback"
    );
    if (!toolUse) {
      throw new Error("Anthropic did not return a submit_feedback tool call");
    }
    return toolUse.input;
  }
};
