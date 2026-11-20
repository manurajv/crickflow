/**
 * Short, user-facing text for any error. Raw Firebase messages
 * ("FirebaseError: Missing or insufficient permissions.") are never shown.
 * Messages written for users (callable function errors, our own
 * `new Error("…")`) pass through.
 */
const GENERIC = "Something went wrong. Please try again.";
const OFFLINE = "No internet connection. Check your connection and try again.";

const CODE_MESSAGES: Record<string, string> = {
  "permission-denied": "You don't have access to this. Refresh or sign in again if you think you should.",
  unauthorized: "You don't have access to this. Refresh or sign in again if you think you should.",
  unauthenticated: "Please sign in to continue.",
  unavailable: OFFLINE,
  "network-request-failed": OFFLINE,
  "deadline-exceeded": OFFLINE,
  "retry-limit-exceeded": OFFLINE,
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

const FIELD_LABELS: Record<string, string> = {
  profilePhotoUrl: "Profile photo",
  nationalIdDocUrl: "National ID document",
  passportDocUrl: "Passport document",
  crickFlowPlayerId: "CrickFlow Player ID",
  fullName: "Full name",
  dateOfBirth: "Date of birth",
  phoneNumber: "Phone",
  nationalId: "National ID",
  passportNumber: "Passport",
};

const CONNECTION_CODES = new Set([
  "unavailable",
  "network-request-failed",
  "deadline-exceeded",
  "retry-limit-exceeded",
]);

function looksTechnical(text: string) {
  return /firestore|insufficient permissions|exception|stack|undefined|null check|grpc|typeerror|cannot read/i.test(
    text,
  );
}

function isConnectionText(text: string) {
  return /socketexception|failed host lookup|network is unreachable|network-request-failed|failed to fetch|clientexception|xmlhttprequest|timeoutexception|offline|no internet|network_error|network error|(timeout.+(connection|network|deadline))/i.test(
    text,
  );
}

function withFieldLabels(message: string) {
  let out = message;
  for (const [key, label] of Object.entries(FIELD_LABELS)) {
    out = out.split(key).join(label);
  }
  return out;
}

export function friendlyError(error: unknown, fallback = GENERIC): string {
  if (error == null) return fallback;
  const rawCode =
    typeof error === "object" && "code" in error ? String((error as { code: unknown }).code ?? "") : "";
  const code = rawCode.includes("/") ? rawCode.split("/").pop() ?? "" : rawCode;
  const message = (error instanceof Error ? error.message : typeof error === "string" ? error : "").trim();

  if (CONNECTION_CODES.has(code) || isConnectionText(message) || isConnectionText(rawCode)) {
    return OFFLINE;
  }
  // Callable functions send messages written for users.
  if (rawCode.startsWith("functions/") && message && !looksTechnical(message)) {
    return withFieldLabels(message);
  }
  if (code && CODE_MESSAGES[code]) return CODE_MESSAGES[code];
  if (/insufficient permissions|permission[-_ ]denied/i.test(message)) return CODE_MESSAGES["permission-denied"];
  if (!message || message.length > 200 || looksTechnical(message)) return fallback;
  return withFieldLabels(message);
}


export function friendlyUploadError(error: unknown, isDocument = true) {
  const limit = isDocument ? "5 MB" : "2 MB";
  const message = error instanceof Error ? error.message : String(error ?? "");
  const rawCode =
    typeof error === "object" && error && "code" in error ? String((error as { code: unknown }).code ?? "") : "";
  const code = rawCode.includes("/") ? rawCode.split("/").pop() ?? "" : rawCode;
  if (CONNECTION_CODES.has(code) || isConnectionText(message) || isConnectionText(rawCode)) {
    return OFFLINE;
  }
  if (code === "unauthorized" || code === "permission-denied" || code === "unauthenticated") {
    return `This photo couldn't be uploaded. It may be too large (max ${limit}), isn't an allowed image type, or you don't have permission.`;
  }
  if (/too large|exceeds the maximum/i.test(message)) {
    return `This photo is too large. Use a photo under ${limit}.`;
  }
  return friendlyError(error);
}
