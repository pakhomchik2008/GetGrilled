import type { SessionStatus } from "./types.js";

const ALLOWED_TRANSITIONS: Record<SessionStatus, SessionStatus[]> = {
  started: ["in_progress"],
  in_progress: ["in_progress", "awaiting_feedback"],
  // in_progress is also the recovery target if evaluation fails after the awaiting_feedback
  // transition — the candidate can retry finishing rather than getting stuck.
  awaiting_feedback: ["completed", "in_progress"],
  completed: []
};

export class InvalidTransitionError extends Error {
  constructor(from: SessionStatus, to: SessionStatus) {
    super(`Invalid session status transition: ${from} -> ${to}`);
  }
}

export function assertTransition(from: SessionStatus, to: SessionStatus): void {
  if (!ALLOWED_TRANSITIONS[from].includes(to)) {
    throw new InvalidTransitionError(from, to);
  }
}
