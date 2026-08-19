import { MatchCentreLoader } from "@/features/matches/match-centre-loader";
import { shellParams } from "@/lib/static-params";

export function generateStaticParams() {
  return shellParams("matchId");
}

export default function MatchScorecardPage() {
  return <MatchCentreLoader initialTab="scorecard" />;
}
