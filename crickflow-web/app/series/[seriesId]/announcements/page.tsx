import { Suspense } from "react";
import { SeriesAnnouncementsPage } from "./announcements-client";
import { shellParams } from "@/lib/static-params";
import { LoadingPage } from "@/components/shared/page-shell";

export function generateStaticParams() {
  return shellParams("seriesId");
}

export default function SeriesAnnouncementsPageRoute() {
  return (
    <Suspense fallback={<LoadingPage title="Loading" />}>
      <SeriesAnnouncementsPage />
    </Suspense>
  );
}
