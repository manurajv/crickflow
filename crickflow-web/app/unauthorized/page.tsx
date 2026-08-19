import Link from "next/link";
import { EmptyState } from "@/components/shared/states";

export default function UnauthorizedPage() {
  return (
    <EmptyState
      title="Sign in required"
      description="This action needs a CrickFlow account. Public match, team, and tournament pages stay viewable without signing in."
      action={
        <Link href="/login" className="text-primary">
          Go to sign in
        </Link>
      }
    />
  );
}
