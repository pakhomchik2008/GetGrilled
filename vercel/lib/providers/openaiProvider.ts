import OpenAI from "openai";
import { FEEDBACK_TOOL } from "../anthropic.js";
import type { LLMProvider } from "./types.js";

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

  async createFeedback(system, messages) {
    const response = await openai.chat.completions.create({
      model: MODEL,
      max_tokens: MAX_TOKENS,
      messages: [{ role: "system", content: system }, ...messages],
      tools: [
        {
          type: "function",
          function: {
            name: FEEDBACK_TOOL.name,
            description: FEEDBACK_TOOL.description,
            parameters: FEEDBACK_TOOL.input_schema
          }
        }
      ],
      tool_choice: { type: "function", function: { name: "submit_feedback" } }
    });
    const toolCall = response.choices[0]?.message?.tool_calls?.[0];
    if (!toolCall) {
      throw new Error("OpenAI did not return a submit_feedback tool call");
    }
    return JSON.parse(toolCall.function.arguments);
  }
};
