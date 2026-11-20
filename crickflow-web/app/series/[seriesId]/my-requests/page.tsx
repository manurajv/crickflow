import { Suspense } from "react";
import { SeriesMyRequestsPage } from "./my-requests-client";
import { shellParams } from "@/lib/static-params";
import { LoadingPage } from "@/components/shared/page-shell";

export function generateStaticParams() {
  return shellParams("seriesId");
}

export default function SeriesMyRequestsPageRoute() {
  return (
    <Suspense fallback={<LoadingPage title="Loading" />}>
      <SeriesMyRequestsPage />
    </Suspense>
  );
}
