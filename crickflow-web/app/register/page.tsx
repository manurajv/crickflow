"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input, Textarea } from "@/components/ui/input";
import { EmptyState } from "@/components/shared/states";
import { useAuth } from "@/features/auth/auth-provider";
import { upsertUserProfile } from "@/repositories";

export default function RegisterPage() {
  const { user, profile, loading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (loading) return;
    if (!user) return;
    if (profile?.onboardingCompleted) router.replace("/");
  }, [loading, user, profile, router]);

  if (loading) return <p>Loading…</p>;
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

  return <OnboardingForm />;
}

function OnboardingForm() {
  const { user, profile, refreshProfile } = useAuth();
  const router = useRouter();
  const [name, setName] = useState(profile?.name || user?.displayName || "");
  const [displayName, setDisplayName] = useState(profile?.displayName || user?.displayName || "");
  const [bio, setBio] = useState(profile?.bio || "");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  if (!user) return null;

  return (
    <Card className="mx-auto max-w-md space-y-4 p-8">
      <h1 className="text-2xl font-bold">Complete your profile</h1>
      <p className="text-sm text-muted-foreground">
        This is the web onboarding step. Creating teams and scoring stays on the CrickFlow app.
      </p>
      <form
        className="space-y-3"
        onSubmit={async (event) => {
          event.preventDefault();
          setBusy(true);
          setError("");
          try {
            await upsertUserProfile({
              id: user.uid,
              email: profile?.email ?? user.email ?? "",
              name: name.trim(),
              displayName: displayName.trim() || name.trim(),
              bio: bio.trim(),
              photoUrl: profile?.photoUrl ?? user.photoURL ?? undefined,
              phoneNumber: profile?.phoneNumber ?? user.phoneNumber ?? undefined,
              role: profile?.role ?? "organizer",
              location: profile?.location ?? {
                country: "",
                stateProvince: "",
                district: "",
                city: "",
                placeName: "",
              },
              onboardingCompleted: true,
            });
            await refreshProfile();
            router.replace("/");
          } catch (err) {
            setError(err instanceof Error ? err.message : "Could not save profile");
          } finally {
            setBusy(false);
          }
        }}
      >
        <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="Full name" required />
        <Input value={displayName} onChange={(e) => setDisplayName(e.target.value)} placeholder="Display name" />
        <Textarea value={bio} onChange={(e) => setBio(e.target.value)} placeholder="Bio (optional)" />
        <Button type="submit" className="w-full" disabled={busy || !name.trim()}>
          Continue
        </Button>
        {error ? <p className="text-sm text-live">{error}</p> : null}
      </form>
    </Card>
  );
}
