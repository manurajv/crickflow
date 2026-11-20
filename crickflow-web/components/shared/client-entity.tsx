"use client";

import { useEffect, useState } from "react";
import { EmptyState } from "@/components/shared/states";

export function ClientEntity<T>({
  load,
  children,
  missingTitle = "Not found",
  missingDescription,
}: {
  load: () => Promise<T | null>;
  children: (data: T) => React.ReactNode;
  /** Shown when the doc no longer exists (e.g. deleted by an admin). */
  missingTitle?: string;
  missingDescription?: string;
}) {
  const [data, setData] = useState<T | null>(null);
  const [missing, setMissing] = useState(false);

  useEffect(() => {
    let cancelled = false;
    load()
      .then((value) => {
        if (cancelled) return;
        if (!value) setMissing(true);
        else setData(value);
      })
      .catch(() => {
        if (!cancelled) setMissing(true);
      });
    return () => {
      cancelled = true;
    };
  }, [load]);

  if (missing) return <EmptyState title={missingTitle} description={missingDescription} />;
  if (!data) return <p>Loading…</p>;
  return <>{children(data)}</>;
}
