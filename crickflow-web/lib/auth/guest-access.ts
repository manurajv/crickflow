import { isSafeNextPath, safeNextPath } from "@/lib/auth/safe-next-path";

/** Whitelisted sign-in gate messages (keys only in URLs — never raw free text). */
export const SIGN_IN_PROMPTS = {
  general: "Sign in to your CrickFlow account to continue.",
  create_post: "Sign in to create a post and join the conversation.",
  create_opportunity: "Sign in to post an opportunity on Discover.",
  like_comment: "Sign in to like and comment on posts.",
  save_post: "Sign in to save posts for later.",
  follow: "Sign in to follow players and build your cricket network.",
  chat: "Sign in to send messages and start chats.",
  report: "Sign in to report content and help keep CrickFlow safe.",
  manage_post: "Sign in to manage this post.",
  block_user: "Sign in to block users.",
  notifications: "Sign in to view your notifications.",
  notification_settings: "Sign in to manage notification preferences.",
  manage_profile: "Sign in to manage your profile.",
  my_cricket: "Sign in to see your matches, teams, stats, and highlights.",
  start_match: "Sign in to start a match and keep score.",
  score_match: "Sign in to score this match.",
  stream_match: "Sign in to stream or broadcast this match.",
  create_team: "Sign in to create a team.",
  manage_team: "Sign in to manage this team.",
  create_tournament: "Sign in to create a tournament.",
  join_tournament: "Sign in to join this tournament.",
  invite_player: "Sign in to invite a player to CrickFlow.",
  create_org: "Sign in to create an organization.",
  create_org_team: "Sign in to add a team to this organization.",
  join_org: "Sign in to join this organization.",
  join_org_team: "Sign in to request to join this team and submit your registration documents.",
  register_org_player: "Sign in to submit player registration documents for this organization.",
  add_org_player: "Sign in to add a player and submit their registration documents.",
  propose_match: "Sign in to propose a match in this organization.",
  propose_tournament: "Sign in to propose a tournament in this organization.",
  org_manage: "Sign in to manage this organization.",
  edit_profile: "Sign in to edit your profile.",
} as const;

export type SignInPromptKey = keyof typeof SIGN_IN_PROMPTS;

/** Default / fallback body (same as Flutter SignInPrompt.general). */
export const SIGN_IN_DEFAULT_MESSAGE = SIGN_IN_PROMPTS.general;

/**
 * @deprecated Use SIGN_IN_DEFAULT_MESSAGE or resolveSignInMessage(key).
 * Kept so older imports keep compiling during the rename.
 */
export const SIGN_IN_TO_USE_THIS = SIGN_IN_DEFAULT_MESSAGE;

export function resolveSignInMessage(keyOrRaw: string | null | undefined): string {
  if (!keyOrRaw) return SIGN_IN_DEFAULT_MESSAGE;
  const key = keyOrRaw.trim();
  if (key in SIGN_IN_PROMPTS) {
    return SIGN_IN_PROMPTS[key as SignInPromptKey];
  }
  // Reject free-text / unknown keys — only the whitelist is shown.
  return SIGN_IN_DEFAULT_MESSAGE;
}

/** Login URL that returns the user to [path] after success. Pass a prompt key. */
export function loginUrl(
  nextPath?: string,
  promptKey: SignInPromptKey = "general",
): string {
  const safe = isSafeNextPath(nextPath) ? safeNextPath(nextPath) : "";
  if (!safe || safe === "/") {
    return `/login?msg=${encodeURIComponent(promptKey)}`;
  }
  return `/login?next=${encodeURIComponent(safe)}&msg=${encodeURIComponent(promptKey)}`;
}
