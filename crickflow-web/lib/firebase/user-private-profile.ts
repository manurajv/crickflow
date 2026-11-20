/** Helpers for users/{uid}/private/profile PII. Keep in sync with the Dart helper. */

export const USER_PRIVATE_COLLECTION = "private";
export const USER_PRIVATE_PROFILE_DOC = "profile";

function nonEmpty(value: unknown): string | undefined {
  if (value == null) return undefined;
  const text = String(value).trim();
  return text.length === 0 ? undefined : text;
}

export function mergePrivateUserProfile(
  parent: Record<string, unknown>,
  privateData?: Record<string, unknown> | null,
): Record<string, unknown> {
  if (!privateData) return { ...parent };
  const out: Record<string, unknown> = { ...parent };
  const email = nonEmpty(privateData.email);
  if (email) out.email = email;
  const phone = nonEmpty(privateData.phoneNumber) ?? nonEmpty(privateData.mobile);
  const mobile = nonEmpty(privateData.mobile) ?? nonEmpty(privateData.phoneNumber);
  if (phone) out.phoneNumber = phone;
  if (mobile) out.mobile = mobile;
  const dob = privateData.dob ?? privateData.dateOfBirth;
  if (dob != null && (typeof dob !== "string" || dob.trim().length > 0)) {
    out.dob = dob;
    out.dateOfBirth = dob;
  }
  return out;
}

export function privateUserProfilePayload(input: {
  email?: string;
  phoneNumber?: string | null;
  dateOfBirth?: string | null;
}): Record<string, unknown> {
  const phone = nonEmpty(input.phoneNumber);
  const payload: Record<string, unknown> = {
    updatedAt: new Date().toISOString(),
  };
  if (input.email !== undefined) payload.email = input.email;
  if (input.phoneNumber !== undefined) {
    payload.phoneNumber = phone ?? null;
    payload.mobile = phone ?? null;
  }
  if (input.dateOfBirth !== undefined) {
    payload.dob = input.dateOfBirth || null;
    payload.dateOfBirth = input.dateOfBirth || null;
  }
  return payload;
}
