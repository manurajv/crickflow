import { TeamProfileClient } from "./team-profile-client";
import { shellParams } from "@/lib/static-params";

export function generateStaticParams() {
  return shellParams("teamId");
}

export default function TeamPage() {
  return <TeamProfileClient />;
}
