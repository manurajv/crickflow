import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import { currentScore, formatMatchWhen, formatOvers, locationLabel, matchStatusLabel } from "@/lib/cricket/format";
import { cn, firstGrapheme } from "@/lib/utils";
import type { Match } from "@/types/models";

function statusVariant(status: string) {
  if (status === "live" || status === "inningsBreak") return "live" as const;
  if (status === "completed" || status === "abandoned") return "completed" as const;
  return "upcoming" as const;
}

export function MatchCard({ match }: { match: Match }) {
  const score = currentScore(match);
  const live = match.status === "live" || match.status === "inningsBreak";
  return (
    <Link href={`/matches/${match.id}`} className="block">
      <Card className={cn("p-5 transition hover:border-primary/40", live && "ring-1 ring-live/40")}>
        <div className="flex items-start justify-between gap-3">
          <div>
            <p className="text-xs text-muted-foreground">
              {match.venue || locationLabel(match.location) || "Venue TBC"}
            </p>
            <h3 className="mt-1 text-base font-semibold">
              {match.teamAName || "Team A"} vs {match.teamBName || "Team B"}
            </h3>
          </div>
          <Badge variant={statusVariant(String(match.status))}>
            {matchStatusLabel(String(match.status))}
          </Badge>
        </div>
        {score ? (
          <p className="mt-3 text-2xl font-bold tracking-tight">
            {score.runs}/{score.wickets}
            <span className="ml-2 text-sm font-medium text-muted-foreground">
              ({score.overs} ov)
            </span>
          </p>
        ) : (
          <p className="mt-3 text-sm text-muted-foreground">
            {formatMatchWhen(match.scheduledAt)}
          </p>
        )}
        {match.resultSummary ? (
          <p className="mt-2 text-sm text-cricket">{match.resultSummary}</p>
        ) : null}
        {live && match.innings[match.currentInningsIndex]?.isFreeHitActive ? (
          <Badge className="mt-3" variant="live">
            Free Hit
          </Badge>
        ) : null}
      </Card>
    </Link>
  );
}

export function EntityCard({
  href,
  title,
  subtitle,
  image,
  meta,
}: {
  href: string;
  title: string;
  subtitle?: string;
  image?: string;
  meta?: string;
}) {
  return (
    <Link href={href} className="block">
      <Card className="flex items-center gap-4 p-4 transition hover:border-primary/40">
        <div
          className="flex h-14 w-14 shrink-0 items-center justify-center overflow-hidden rounded-xl bg-muted text-lg font-bold"
          suppressHydrationWarning
        >
          {image?.trim() ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={image} alt="" className="h-full w-full object-cover" />
          ) : (
            firstGrapheme(title)
          )}
        </div>
        <div className="min-w-0">
          <h3 className="truncate font-semibold">{title}</h3>
          {subtitle ? <p className="truncate text-sm text-muted-foreground">{subtitle}</p> : null}
          {meta ? <p className="text-xs text-muted-foreground">{meta}</p> : null}
        </div>
      </Card>
    </Link>
  );
}

export { formatOvers };
