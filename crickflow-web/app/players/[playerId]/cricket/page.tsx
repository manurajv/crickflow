import type { Metadata } from "next";
import { CricketProfilePage } from "@/features/profiles/cricket/cricket-profile-page";
import { shellParams } from "@/lib/static-params";

export function generateStaticParams() {
  return shellParams("playerId");
}

export const metadata: Metadata = {
  title: "Cricket profile",
  description: "Player batting, bowling, fielding, trophies, badges, and teams.",
};

export default function Page() {
  return <CricketProfilePage />;
}
