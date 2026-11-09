/** Same copy as the Flutter app (kSignInToUseThisMessage). */
export const SIGN_IN_TO_USE_THIS = "Sign in to use this";

/** Login URL that returns the user to [path] after success. */
export function loginUrl(nextPath?: string): string {
  if (!nextPath || !nextPath.startsWith("/")) return "/login";
  return `/login?next=${encodeURIComponent(nextPath)}&msg=${encodeURIComponent(SIGN_IN_TO_USE_THIS)}`;
}
