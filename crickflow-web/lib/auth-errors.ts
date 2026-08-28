export function authErrorMessage(error: unknown): string {
  const code =
    typeof error === "object" && error && "code" in error ? String((error as { code: string }).code) : "";
  switch (code) {
    case "auth/unauthorized-domain":
      return "This site is not yet on Firebase Auth authorized domains. Add crickflow.web.app in the Firebase Console.";
    case "auth/popup-blocked":
      return "The sign-in popup was blocked. Allow popups or try again.";
    case "auth/operation-not-allowed":
      return "This sign-in method is disabled in Firebase Authentication.";
    case "auth/invalid-phone-number":
      return "Enter a full number with country code, for example +94…";
    case "auth/invalid-verification-code":
      return "That code is incorrect. Request a new OTP and try again.";
    case "auth/invalid-email":
      return "Enter a valid email address.";
    case "auth/email-already-in-use":
      return "That email already has an account. Sign in instead.";
    case "auth/weak-password":
      return "Use a password with at least 6 characters.";
    case "auth/user-not-found":
    case "auth/wrong-password":
    case "auth/invalid-credential":
      return "Email or password is incorrect.";
    case "auth/too-many-requests":
      return "Too many attempts. Wait a bit and try again.";
    case "auth/captcha-check-failed":
    case "auth/invalid-app-credential":
      return "Phone verification failed the security check. Refresh the page and try again, or use Google.";
    case "auth/missing-phone-number":
      return "Enter a full number with country code, for example +94…";
    case "auth/quota-exceeded":
      return "SMS quota exceeded for this project. Try Google sign-in or try again later.";
    case "functions/permission-denied":
    case "permission-denied":
      return error instanceof Error && error.message
        ? error.message
        : "Sign in with Google or the invited mobile number to accept.";
    default:
      return error instanceof Error ? error.message : "Sign-in failed";
  }
}
