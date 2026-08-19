import { PlayerProfileClient } from "./player-profile-client";
import { shellParams } from "@/lib/static-params";

export function generateStaticParams() {
  return shellParams("playerId");
}

export default function PlayerPage() {
  return <PlayerProfileClient />;
}
