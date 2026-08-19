import { CommunityPostClient } from "./community-post-client";
import { shellParams } from "@/lib/static-params";

export function generateStaticParams() {
  return shellParams("postId");
}

export default function CommunityPostPage() {
  return <CommunityPostClient />;
}
