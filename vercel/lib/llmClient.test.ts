import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("./providers/anthropicProvider.js", () => ({
  anthropicProvider: { name: "anthropic", streamText: vi.fn(), createFeedback: vi.fn() }
}));
vi.mock("./providers/openaiProvider.js", () => ({
  openaiProvider: { name: "openai", streamText: vi.fn(), createFeedback: vi.fn() }
}));

import { anthropicProvider } from "./providers/anthropicProvider.js";
import { openaiProvider } from "./providers/openaiProvider.js";
import { createFeedback, streamText } from "./llmClient.js";

beforeEach(() => {
  vi.clearAllMocks();
});

describe("streamText fallback", () => {
  it("uses Anthropic when it succeeds", async () => {
    vi.mocked(anthropicProvider.streamText).mockImplementation(async (_s, _m, onDelta) => {
      onDelta("hi");
      return "hi";
    });
    const deltas: string[] = [];
    const result = await streamText("system", [], (t) => deltas.push(t));
    expect(result).toBe("hi");
    expect(deltas).toEqual(["hi"]);
    expect(openaiProvider.streamText).not.toHaveBeenCalled();
  });

  it("falls back to OpenAI when Anthropic fails before sending anything", async () => {
    vi.mocked(anthropicProvider.streamText).mockRejectedValue(new Error("no credits"));
    vi.mocked(openaiProvider.streamText).mockImplementation(async (_s, _m, onDelta) => {
      onDelta("fallback");
      return "fallback";
    });
    const deltas: string[] = [];
    const result = await streamText("system", [], (t) => deltas.push(t));
    expect(result).toBe("fallback");
    expect(deltas).toEqual(["fallback"]);
  });

  it("does not fall back once Anthropic has already streamed partial output", async () => {
    vi.mocked(anthropicProvider.streamText).mockImplementation(async (_s, _m, onDelta) => {
      onDelta("partial");
      throw new Error("dropped mid-stream");
    });
    const deltas: string[] = [];
    await expect(streamText("system", [], (t) => deltas.push(t))).rejects.toThrow("dropped mid-stream");
    expect(deltas).toEqual(["partial"]);
    expect(openaiProvider.streamText).not.toHaveBeenCalled();
  });

  it("throws the last error when every provider fails", async () => {
    vi.mocked(anthropicProvider.streamText).mockRejectedValue(new Error("anthropic down"));
    vi.mocked(openaiProvider.streamText).mockRejectedValue(new Error("openai down"));
    await expect(streamText("system", [], () => {})).rejects.toThrow("openai down");
  });
});

describe("createFeedback fallback", () => {
  it("falls back to OpenAI when Anthropic fails", async () => {
    vi.mocked(anthropicProvider.createFeedback).mockRejectedValue(new Error("no credits"));
    vi.mocked(openaiProvider.createFeedback).mockResolvedValue({ ok: true });
    const result = await createFeedback("system", []);
    expect(result).toEqual({ ok: true });
  });
});
