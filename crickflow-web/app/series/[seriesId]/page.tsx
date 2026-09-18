import { SeriesDetailPage } from "./series-detail-client";
import { shellParams } from "@/lib/static-params";

export function generateStaticParams() {
  return shellParams("seriesId");
}

export default function SeriesDetailRoute() {
  return <SeriesDetailPage />;
}
