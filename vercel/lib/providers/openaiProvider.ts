import OpenAI from "openai";
import type { LLMMessage, LLMProvider, ToolDefinition } from "./types.js";

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

const MODEL = "gpt-4o";
const MAX_TOKENS = 2048;

// OpenAI only allows image_url parts on user messages (assistant content is text-only), so
// this branches per role rather than mapping generically — our transcript never attaches an
// image to an interviewer/assistant turn anyway.
function toOpenAIMessages(messages: LLMMessage[]): OpenAI.ChatCompletionMessageParam[] {
  return messages.map((message): OpenAI.ChatCompletionMessageParam => {
    if (message.role === "assistant") {
      return {
        role: "assistant",
        content: typeof message.content === "string" ? message.content : message.content.map((part) => (part.type === "text" ? part.text : "")).join("")
      };
    }
    return {
      role: "user",
      content:
        typeof message.content === "string"
          ? message.content
          : message.content.map((part) =>
              part.type === "text"
                ? { type: "text" as const, text: part.text }
                : { type: "image_url" as const, image_url: { url: `data:${part.mediaType};base64,${part.base64}` } }
            )
    };
  });
}

export const openaiProvider: LLMProvider = {
  name: "openai",

  async streamText(system, messages, onDelta) {
    const stream = await openai.chat.completions.create({
      model: MODEL,
      max_tokens: MAX_TOKENS,
      stream: true,
      messages: [{ role: "system", content: system }, ...toOpenAIMessages(messages)]
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
      messages: [{ role: "system", content: system }, ...toOpenAIMessages(messages)],
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
