import { Suspense } from "react";
import { SeriesDirectoryClient } from "./series-directory-client";
import { LoadingPage } from "@/components/shared/page-shell";

export default function SeriesPage() {
  return (
    <Suspense fallback={<LoadingPage title="Loading organizations" />}>
      <SeriesDirectoryClient />
    </Suspense>
  );
}
