"use client";

import { useQuery } from "@tanstack/react-query";
import { AppLink as Link } from "@/components/shared/app-link";
import { LoadingPage } from "@/components/shared/page-shell";
import { Button } from "@/components/ui/button";
import { useAuth } from "@/features/auth/auth-provider";
import { CricketProfileView } from "@/features/profiles/cricket/cricket-profile-view";
import { loginUrl } from "@/lib/auth/guest-access";
import { getPlayerByUserId } from "@/repositories";

export default function MyCricketProfilePage() {
  const { user, loading } = useAuth();
  const playerQuery = useQuery({
    queryKey: ["linked-player", user?.uid],
    queryFn: () => getPlayerByUserId(user!.uid),
    enabled: Boolean(user?.uid),
  });

  if (loading || (user && playerQuery.isPending)) {
    return <LoadingPage title="Loading cricket profile" />;
  }
  if (!user) {
    return (
      <div className="mx-auto max-w-3xl px-4 py-12">
        <h1 className="text-3xl font-black">Your cricket profile</h1>
        <p className="mt-3 text-muted-foreground">Sign in to see the same cricket profile that appears in the app.</p>
        <Button className="mt-6" asChild>
          <Link href={loginUrl("/profile/cricket", "my_cricket")}>Sign in</Link>
        </Button>
      </div>
    );
  }
  if (!playerQuery.data) {
    return (
      <div className="mx-auto max-w-3xl px-4 py-12">
        <h1 className="text-3xl font-black">Your cricket profile</h1>
        <p className="mt-3 text-muted-foreground">
          No linked player profile was found yet. Complete your player profile to see batting, bowling, and fielding stats here.
        </p>
        <Button className="mt-6" asChild>
          <Link href="/profile">Back to profile</Link>
        </Button>
      </div>
    );
  }
  return <CricketProfileView playerId={playerQuery.data.id} backHref="/profile" />;
}
