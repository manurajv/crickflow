"use client";

import { siteConfig } from "@/config/site";
import { Button } from "@/components/ui/button";

export function GetTheApp({
  title = "Create teams and tournaments in the CrickFlow app",
  description = "Scoring, squads, and tournament setup stay on mobile. The web app is the public viewer.",
}: {
  title?: string;
  description?: string;
}) {
  return (
    <div className="rounded-2xl border border-border bg-card p-5">
      <p className="font-semibold">{title}</p>
      <p className="mt-1 text-sm text-muted-foreground">{description}</p>
      <Button className="mt-3" asChild>
        <a href={siteConfig.playStoreUrl} target="_blank" rel="noreferrer">
          Get CrickFlow on Google Play
        </a>
      </Button>
    </div>
  );
}
