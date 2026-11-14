import { Suspense } from "react";
import { SeriesSettingsPage } from "./settings-client";
import { shellParams } from "@/lib/static-params";
import { LoadingPage } from "@/components/shared/page-shell";

export function generateStaticParams() {
  return shellParams("seriesId");
}

export default function SeriesSettingsPageRoute() {
  return (
    <Suspense fallback={<LoadingPage title="Loading" />}>
      <SeriesSettingsPage />
    </Suspense>
  );
}
