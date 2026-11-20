import { doc, getDoc } from "firebase/firestore";
import { collections } from "@/config/site";
import { getDb } from "@/lib/firebase/client";

export type PlatformAdminInfo = {
  isPlatformAdmin: boolean;
  roleId?: string;
};

/** Active web-admin profile in additive `admin_users` (superAdmin / staff). */
export async function getPlatformAdminInfo(uid: string): Promise<PlatformAdminInfo> {
  if (!uid) return { isPlatformAdmin: false };
  try {
    const snap = await getDoc(doc(getDb(), collections.adminUsers, uid));
    if (!snap.exists()) return { isPlatformAdmin: false };
    const data = snap.data() as Record<string, unknown>;
    const roleId = typeof data.roleId === "string" ? data.roleId : "";
    const isActive = data.isActive !== false;
    if (!isActive || !roleId) return { isPlatformAdmin: false };
    return { isPlatformAdmin: true, roleId };
  } catch {
    return { isPlatformAdmin: false };
  }
}

export function profileNeedsPlayerOnboarding(
  profile: { onboardingCompleted?: boolean } | null | undefined,
  isPlatformAdmin: boolean,
): boolean {
  if (isPlatformAdmin) return false;
  if (!profile) return true;
  return !profile.onboardingCompleted;
}
