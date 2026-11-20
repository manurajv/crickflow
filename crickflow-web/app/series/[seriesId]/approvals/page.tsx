import { Suspense } from "react";
import { SeriesApprovalsPage } from "./approvals-client";
import { shellParams } from "@/lib/static-params";
import { LoadingPage } from "@/components/shared/page-shell";

export function generateStaticParams() {
  return shellParams("seriesId");
}

export default function SeriesApprovalsPageRoute() {
  return (
    <Suspense fallback={<LoadingPage title="Loading" />}>
      <SeriesApprovalsPage />
    </Suspense>
  );
}
