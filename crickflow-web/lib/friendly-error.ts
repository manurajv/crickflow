/**
 * Short, user-facing text for any error. Raw Firebase messages
 * ("FirebaseError: Missing or insufficient permissions.") are never shown.
 * Messages written for users (callable function errors, our own
 * `new Error("…")`) pass through.
 */
const GENERIC = "Something went wrong. Please try again.";

const CODE_MESSAGES: Record<string, string> = {
  "permission-denied": "You don't have access to this. Refresh or sign in again if you think you should.",
  unauthorized: "You don't have access to this. Refresh or sign in again if you think you should.",
  unauthenticated: "Please sign in to continue.",
  unavailable: "Connection problem. Check your internet and try again.",
  "network-request-failed": "Connection problem. Check your internet and try again.",
  "deadline-exceeded": "This is taking too long. Please try again.",
  "not-found": "This item is no longer available.",
  "object-not-found": "This file is no longer available.",
  "already-exists": "This already exists.",
  "resource-exhausted": "Too many requests. Please wait a moment and try again.",
  "quota-exceeded": "Too many requests. Please wait a moment and try again.",
  "too-many-requests": "Too many attempts. Please wait a moment and try again.",
  aborted: "Someone else changed this at the same time. Please try again.",
  "failed-precondition": "This can't be done right now. Please try again.",
  "invalid-argument": "Some details aren't valid. Please check and try again.",
  internal: GENERIC,
  unknown: GENERIC,
};

function looksTechnical(text: string) {
  return /firebase|firestore|insufficient permissions|exception|stack|undefined|null|grpc|typeerror|cannot read/i.test(
    text,
  );
}

export function friendlyError(error: unknown, fallback = GENERIC): string {
  if (error == null) return fallback;
  const rawCode =
    typeof error === "object" && "code" in error ? String((error as { code: unknown }).code ?? "") : "";
  const code = rawCode.includes("/") ? rawCode.split("/").pop() ?? "" : rawCode;
  const message = (error instanceof Error ? error.message : typeof error === "string" ? error : "").trim();

  // Callable functions send messages written for users.
  if (rawCode.startsWith("functions/") && message && message.length <= 160 && !looksTechnical(message)) {
    return message;
  }
  if (code && CODE_MESSAGES[code]) return CODE_MESSAGES[code];
  if (/insufficient permissions|permission[-_ ]denied/i.test(message)) return CODE_MESSAGES["permission-denied"];
  if (/failed to fetch|network|offline/i.test(message)) return CODE_MESSAGES.unavailable;
  if (!message || message.length > 160 || looksTechnical(message)) return fallback;
  return message;
}
