"use client";

import { CricketProfileView } from "@/features/profiles/cricket/cricket-profile-view";
import { usePathParam } from "@/lib/use-path-param";

export function CricketProfilePage() {
  const playerId = usePathParam("playerId", 1);
  return <CricketProfileView playerId={playerId} />;
}
