import { Suspense } from "react";
import { OrgTeamDetailPage } from "./team-detail-client";
import { LoadingPage } from "@/components/shared/page-shell";

export function generateStaticParams() {
  return [{ seriesId: "_", clubId: "_" }];
}

export default function OrgTeamDetailRoute() {
  return (
    <Suspense fallback={<LoadingPage title="Loading team" />}>
      <OrgTeamDetailPage />
    </Suspense>
  );
}
