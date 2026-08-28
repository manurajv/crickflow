"use client";

import { usePathname, useRouter } from "next/navigation";
import { useEffect } from "react";
import { useAuth } from "@/features/auth/auth-provider";

function isOnboardingExempt(pathname: string) {
  if (pathname === "/login" || pathname === "/register") return true;
  if (pathname.startsWith("/invite/")) return true;
  if (pathname.startsWith("/legal/")) return true;
  return false;
}

export function OnboardingGuard({ children }: { children: React.ReactNode }) {
  const { user, profile, loading } = useAuth();
  const pathname = usePathname();
  const router = useRouter();

  useEffect(() => {
    if (loading) return;
    if (!user || !profile) return;
    if (profile.onboardingCompleted) return;
    if (isOnboardingExempt(pathname)) return;
    router.replace("/register");
  }, [loading, user, profile, pathname, router]);

  if (!loading && user && profile && !profile.onboardingCompleted && !isOnboardingExempt(pathname)) {
    return (
      <div className="flex min-h-[40vh] items-center justify-center text-sm text-muted-foreground">
        Redirecting to profile setup…
      </div>
    );
  }

  return children;
}
