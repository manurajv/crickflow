const neverKey = (uid: string) => `cf_org_welcome_never_${uid}`;
const seenKey = (uid: string, seriesId: string) =>
  `cf_org_welcome_seen_${uid}_${seriesId}`;

export function shouldShowOrgWelcome(
  uid: string,
  seriesId: string,
  fromCreate: boolean,
): boolean {
  if (typeof window === "undefined") return false;
  try {
    if (localStorage.getItem(neverKey(uid)) === "1") return false;
    if (fromCreate) return true;
    return localStorage.getItem(seenKey(uid, seriesId)) !== "1";
  } catch {
    return fromCreate;
  }
}

/** Show once per org unless never-ask; fromCreate always eligible if not never. */
export function markOrgWelcomeSeen(
  uid: string,
  seriesId: string,
  neverAgain: boolean,
): void {
  if (typeof window === "undefined") return;
  try {
    localStorage.setItem(seenKey(uid, seriesId), "1");
    if (neverAgain) localStorage.setItem(neverKey(uid), "1");
  } catch {
    /* ignore */
  }
}
