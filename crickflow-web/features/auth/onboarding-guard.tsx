"use client";

import { usePathname, useRouter } from "next/navigation";
import { useEffect } from "react";
import { useAuth } from "@/features/auth/auth-provider";
import { normalizePathname, pathStartsWith, pathsEqual } from "@/lib/routing/paths";

function isOnboardingExempt(pathname: string) {
  const path = normalizePathname(pathname);
  if (pathsEqual(path, "/login") || pathsEqual(path, "/register")) return true;
  if (pathStartsWith(path, "/invite")) return true;
  if (pathStartsWith(path, "/legal")) return true;
  return false;
}

function needsOnboarding(
  profile: { onboardingCompleted?: boolean } | null,
): boolean {
  // Signed-in with no profile yet still must finish setup (create may have failed).
  if (!profile) return true;
  return !profile.onboardingCompleted;
}

export function OnboardingGuard({ children }: { children: React.ReactNode }) {
  const { user, profile, loading } = useAuth();
  const pathname = usePathname();
  const router = useRouter();
  const blocked =
    !loading && Boolean(user) && needsOnboarding(profile) && !isOnboardingExempt(pathname);

  useEffect(() => {
    if (!blocked) return;
    // Prefer trailing slash for static export hosting.
    router.replace("/register/");
  }, [blocked, router]);

  if (blocked) {
    return (
      <div className="flex min-h-[40vh] items-center justify-center text-sm text-muted-foreground">
        Redirecting to profile setup…
      </div>
    );
  }

  return children;
}
