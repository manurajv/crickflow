import { Suspense } from "react";
import { JoinRequestDetailPage } from "./detail-client";
import { LoadingPage } from "@/components/shared/page-shell";

export function generateStaticParams() {
  return [{ seriesId: "_", approvalId: "_" }];
}

export default function JoinRequestDetailRoute() {
  return (
    <Suspense fallback={<LoadingPage title="Loading request" />}>
      <JoinRequestDetailPage />
    </Suspense>
  );
}
