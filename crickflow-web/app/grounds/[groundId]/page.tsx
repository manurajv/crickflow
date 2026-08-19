import { GroundProfileClient } from "./ground-profile-client";
import { shellParams } from "@/lib/static-params";

export function generateStaticParams() {
  return shellParams("groundId");
}

export default function GroundPage() {
  return <GroundProfileClient />;
}
