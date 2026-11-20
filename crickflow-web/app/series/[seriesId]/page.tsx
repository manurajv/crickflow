import { Suspense } from "react";
import { SeriesDetailPage } from "./series-detail-client";
import { shellParams } from "@/lib/static-params";
import { LoadingPage } from "@/components/shared/page-shell";

export function generateStaticParams() {
  return shellParams("seriesId");
}

export default function SeriesDetailRoute() {
  return (
    <Suspense fallback={<LoadingPage title="Loading organization" />}>
      <SeriesDetailPage />
    </Suspense>
  );
}
