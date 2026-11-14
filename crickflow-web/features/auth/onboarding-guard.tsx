"use client";

import { usePathname, useRouter } from "next/navigation";
import { useEffect } from "react";
import { useAuth } from "@/features/auth/auth-provider";
import { normalizePathname, pathStartsWith, pathsEqual } from "@/lib/routing/paths";
import { profileNeedsPlayerOnboarding } from "@/lib/auth/platform-admin";

function isOnboardingExempt(pathname: string) {
  const path = normalizePathname(pathname);
  if (pathsEqual(path, "/login") || pathsEqual(path, "/register")) return true;
  if (pathStartsWith(path, "/invite")) return true;
  if (pathStartsWith(path, "/legal")) return true;
  return false;
}

export function OnboardingGuard({ children }: { children: React.ReactNode }) {
  const { user, profile, isPlatformAdmin, loading } = useAuth();
  const pathname = usePathname();
  const router = useRouter();
  const needs = profileNeedsPlayerOnboarding(profile, isPlatformAdmin);
  const blocked = !loading && Boolean(user) && needs && !isOnboardingExempt(pathname);

  useEffect(() => {
    if (!blocked) return;
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
