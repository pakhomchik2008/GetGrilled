import { describe, expect, it } from "vitest";
import { InvalidTransitionError, assertTransition } from "./statusMachine.js";

describe("assertTransition", () => {
  it("allows the happy path through the full session lifecycle", () => {
    expect(() => assertTransition("started", "in_progress")).not.toThrow();
    expect(() => assertTransition("in_progress", "in_progress")).not.toThrow();
    expect(() => assertTransition("in_progress", "awaiting_feedback")).not.toThrow();
    expect(() => assertTransition("awaiting_feedback", "completed")).not.toThrow();
  });

  it("allows retrying from awaiting_feedback back to in_progress after a failed evaluation", () => {
    expect(() => assertTransition("awaiting_feedback", "in_progress")).not.toThrow();
  });

  it("rejects skipping straight from started to completed", () => {
    expect(() => assertTransition("started", "completed")).toThrow(InvalidTransitionError);
  });

  it("rejects any transition out of completed", () => {
    expect(() => assertTransition("completed", "in_progress")).toThrow(InvalidTransitionError);
    expect(() => assertTransition("completed", "started")).toThrow(InvalidTransitionError);
  });

  it("rejects going backwards from in_progress to started", () => {
    expect(() => assertTransition("in_progress", "started")).toThrow(InvalidTransitionError);
  });
});
