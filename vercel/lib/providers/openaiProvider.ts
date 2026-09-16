import OpenAI from "openai";
import type { LLMProvider, ToolDefinition } from "./types.js";

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

const MODEL = "gpt-4o";
const MAX_TOKENS = 2048;

export const openaiProvider: LLMProvider = {
  name: "openai",

  async streamText(system, messages, onDelta) {
    const stream = await openai.chat.completions.create({
      model: MODEL,
      max_tokens: MAX_TOKENS,
      stream: true,
      messages: [{ role: "system", content: system }, ...messages]
    });
    let full = "";
    for await (const chunk of stream) {
      const text = chunk.choices[0]?.delta?.content;
      if (text) {
        full += text;
        onDelta(text);
      }
    }
    return full;
  },

  async callTool(system, messages, tool: ToolDefinition) {
    const response = await openai.chat.completions.create({
      model: MODEL,
      max_tokens: MAX_TOKENS,
      messages: [{ role: "system", content: system }, ...messages],
      tools: [
        {
          type: "function",
          function: {
            name: tool.name,
            description: tool.description,
            parameters: tool.input_schema
          }
        }
      ],
      tool_choice: { type: "function", function: { name: tool.name } }
    });
    const toolCall = response.choices[0]?.message?.tool_calls?.[0];
    if (!toolCall) {
      throw new Error(`OpenAI did not return a ${tool.name} tool call`);
    }
    return JSON.parse(toolCall.function.arguments);
  }
};
