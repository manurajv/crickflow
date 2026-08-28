import { InviteLanding } from "@/features/invite/invite-landing";
import { shellParams } from "@/lib/static-params";

export function generateStaticParams() {
  return shellParams("token");
}

export default function PlayerInvitePage() {
  return <InviteLanding />;
}
