import {
  PhoneAuthProvider,
  RecaptchaVerifier,
  signInWithCredential,
  signInWithPhoneNumber,
  type Auth,
} from "firebase/auth";

/** Firebase Auth expects E.164 (`+94771234567`). */
export function normalizePhoneE164(raw: string): string {
  const trimmed = raw.trim().replace(/[\s\-()]/g, "");
  if (!trimmed) return "";
  if (trimmed.startsWith("+")) return `+${trimmed.slice(1).replace(/\D/g, "")}`;
  const digits = trimmed.replace(/\D/g, "");
  return digits ? `+${digits}` : "";
}

const E164 = /^\+[1-9]\d{6,14}$/;

export function assertValidPhoneE164(e164: string): void {
  if (!E164.test(e164)) {
    const err = new Error("Enter a full number with country code, for example +94…");
    (err as Error & { code: string }).code = "auth/invalid-phone-number";
    throw err;
  }
}

const verifiers = new Map<string, RecaptchaVerifier>();

function resetVerifier(containerId: string) {
  const existing = verifiers.get(containerId);
  if (existing) {
    try {
      existing.clear();
    } catch {
      /* already cleared */
    }
    verifiers.delete(containerId);
  }
}

/**
 * Returns a stable invisible reCAPTCHA verifier for [containerId].
 * Do not call `.render()` — `signInWithPhoneNumber` drives the challenge.
 */
function getOrCreateVerifier(auth: Auth, containerId: string): RecaptchaVerifier {
  const cached = verifiers.get(containerId);
  if (cached) return cached;

  const el = typeof document !== "undefined" ? document.getElementById(containerId) : null;
  if (!el) {
    throw new Error("Phone verification is not ready yet. Wait a moment and try again.");
  }

  const verifier = new RecaptchaVerifier(auth, containerId, {
    size: "invisible",
    callback: () => undefined,
    "expired-callback": () => resetVerifier(containerId),
  });
  verifiers.set(containerId, verifier);
  return verifier;
}

export async function sendPhoneVerificationCode(
  auth: Auth,
  phone: string,
  containerId: string,
): Promise<string> {
  const e164 = normalizePhoneE164(phone);
  assertValidPhoneE164(e164);

  auth.languageCode = "en";
  const verifier = getOrCreateVerifier(auth, containerId);

  try {
    const confirmation = await signInWithPhoneNumber(auth, e164, verifier);
    return confirmation.verificationId;
  } catch (error) {
    resetVerifier(containerId);
    throw error;
  }
}

export async function confirmPhoneVerificationCode(
  auth: Auth,
  verificationId: string,
  code: string,
): Promise<void> {
  const credential = PhoneAuthProvider.credential(verificationId, code.trim());
  await signInWithCredential(auth, credential);
}

export function resetPhoneRecaptcha(containerId?: string) {
  if (containerId) {
    resetVerifier(containerId);
    return;
  }
  for (const id of [...verifiers.keys()]) {
    resetVerifier(id);
  }
}
