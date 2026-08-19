"use client";

import { useParams, usePathname } from "next/navigation";

export function usePathParam(paramName: string, segmentIndex: number): string {
  const params = useParams();
  const pathname = usePathname();
  const raw = params?.[paramName];
  const fromParams = Array.isArray(raw) ? raw[0] : raw;
  if (fromParams && fromParams !== "_") return fromParams;
  const parts = pathname.split("/").filter(Boolean);
  const fromPath = parts[segmentIndex] ?? "";
  return fromPath === "_" ? "" : fromPath;
}
