"use client";

import { useEffect } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { EmptyState } from "@/components/shared/states";
import { LoadingPage } from "@/components/shared/page-shell";
import { PlayerOnboardingForm } from "@/features/onboarding/player-onboarding-form";
import { useAuth } from "@/features/auth/auth-provider";

export default function RegisterPage() {
  const { user, profile, loading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (loading) return;
    if (!user) return;
    if (profile?.onboardingCompleted) router.replace("/");
  }, [loading, user, profile, router]);

  if (loading) return <LoadingPage title="Loading registration" />;
  if (!user) {
    return (
      <EmptyState
        title="Create your CrickFlow profile"
        description="Sign in with Google or phone first — same account as the mobile app."
        action={
          <Link href="/login?next=/register" className="text-primary">
            Sign in
          </Link>
        }
      />
    );
  }

  return <PlayerOnboardingForm user={user} profile={profile} />;
}
