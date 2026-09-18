import { AppLink as Link } from "@/components/shared/app-link";
import { EmptyState } from "@/components/shared/states";

export default function NotFound() {
  return (
    <EmptyState
      title="Not found"
      description="This CrickFlow page does not exist or is no longer public."
      action={
        <Link href="/" className="text-primary">
          Back home
        </Link>
      }
    />
  );
}
