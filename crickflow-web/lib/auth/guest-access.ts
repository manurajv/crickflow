/** Same copy as the Flutter app (kLoginToUseThisMessage). */
export const LOGIN_TO_USE_THIS = "Login to use this";

/** Login URL that returns the user to [path] after success. */
export function loginUrl(nextPath?: string): string {
  if (!nextPath || !nextPath.startsWith("/")) return "/login";
  return `/login?next=${encodeURIComponent(nextPath)}&msg=${encodeURIComponent(LOGIN_TO_USE_THIS)}`;
}
