import { Suspense } from "react";
import { SeriesAdminsPage } from "./admins-client";
import { shellParams } from "@/lib/static-params";
import { LoadingPage } from "@/components/shared/page-shell";

export function generateStaticParams() {
  return shellParams("seriesId");
}

export default function SeriesAdminsPageRoute() {
  return (
    <Suspense fallback={<LoadingPage title="Loading" />}>
      <SeriesAdminsPage />
    </Suspense>
  );
}
