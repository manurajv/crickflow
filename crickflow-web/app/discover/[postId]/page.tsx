import { DiscoverPostClient } from "./discover-post-client";
import { shellParams } from "@/lib/static-params";

export function generateStaticParams() {
  return shellParams("postId");
}

export default function DiscoverPostPage() {
  return <DiscoverPostClient />;
}
