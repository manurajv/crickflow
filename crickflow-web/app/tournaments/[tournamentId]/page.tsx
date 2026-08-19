import { TournamentProfileClient } from "./tournament-profile-client";
import { shellParams } from "@/lib/static-params";

export function generateStaticParams() {
  return shellParams("tournamentId");
}

export default function TournamentPage() {
  return <TournamentProfileClient />;
}
