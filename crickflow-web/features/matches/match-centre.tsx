"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import {
  Bar,
  BarChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { EmptyState, ErrorState } from "@/components/shared/states";
import { GetTheApp } from "@/components/shared/get-the-app";
import { formatMatchWhen, formatOvers, locationLabel, matchStatusLabel, strikeRate } from "@/lib/cricket/format";
import { eventTypeLabel, extrasFromEvents } from "@/lib/cricket/events";
import { FollowShare } from "@/features/profiles/follow-share";
import { youtubeEmbedId } from "@/lib/utils";
import { listBallEvents, listFantasyLeaguesForMatch, listHighlights, watchBallEvents, watchMatch, watchOverlay } from "@/repositories";
import { LIVE_STATUSES } from "@/types/enums";
import type { BallEvent, FantasyLeague, Match, MatchHighlight, OverlayState } from "@/types/models";

type Tab =
  | "scorecard"
  | "commentary"
  | "stats"
  | "wagon"
  | "manhattan"
  | "partnerships"
  | "players"
  | "highlights";

export function MatchCentre({
  initialMatch,
  initialEvents,
  initialTab = "scorecard",
  watchMode = false,
}: {
  initialMatch: Match;
  initialEvents: BallEvent[];
  initialTab?: Tab;
  watchMode?: boolean;
}) {
  const [match, setMatch] = useState(initialMatch);
  const [overlay, setOverlay] = useState<OverlayState | null>(null);
  const [events, setEvents] = useState(initialEvents);
  const [highlights, setHighlights] = useState<MatchHighlight[]>([]);
  const [tab, setTab] = useState<Tab>(initialTab);
  const [error, setError] = useState<string | null>(null);
  const live = LIVE_STATUSES.includes(String(match.status) as never);
  const innings = match.innings[match.currentInningsIndex];
  const bpo = match.rules.ballsPerOver || 6;
  const videoId = youtubeEmbedId(match.stream.youtubeWatchUrl);

  useEffect(() => {
    if (!live) return;
    const unsubMatch = watchMatch(match.id, (next) => {
      if (next) setMatch(next);
    });
    const unsubOverlay = watchOverlay(match.id, setOverlay);
    const unsubEvents = watchBallEvents(match.id, setEvents);
    return () => {
      unsubMatch();
      unsubOverlay();
      unsubEvents();
    };
  }, [live, match.id]);

  useEffect(() => {
    if (live) return;
    listBallEvents(match.id, 200)
      .then(setEvents)
      .catch(() => setError("Could not load commentary"));
  }, [live, match.id]);

  useEffect(() => {
    listHighlights(match.id).then(setHighlights).catch(() => setHighlights([]));
  }, [match.id]);

  const manhattan = useMemo(() => {
    const buckets = new Map<number, { over: number; runs: number; wickets: number }>();
    for (const event of events) {
      const current = buckets.get(event.overNumber) ?? {
        over: event.overNumber,
        runs: 0,
        wickets: 0,
      };
      current.runs += event.runs;
      if (event.isWicket && event.eventType !== "retiredHurt") current.wickets += 1;
      buckets.set(event.overNumber, current);
    }
    return [...buckets.values()].sort((a, b) => a.over - b.over);
  }, [events]);

  if (error) return <ErrorState description={error} onRetry={() => setError(null)} />;

  return (
    <div className="space-y-6">
      <header className="rounded-2xl border border-border bg-scoreboard p-6 text-white">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <div className="flex items-center gap-2">
              {live ? <Badge variant="live">Live</Badge> : <Badge variant="completed">{matchStatusLabel(String(match.status))}</Badge>}
              {innings?.isFreeHitActive || overlay?.isFreeHit ? (
                <Badge variant="live">Free Hit</Badge>
              ) : null}
            </div>
            <h1 className="mt-2 text-2xl font-bold md:text-3xl">
              {match.teamAId ? (
                <Link className="hover:underline" href={`/teams/${match.teamAId}`}>
                  {match.teamAName}
                </Link>
              ) : (
                match.teamAName
              )}{" "}
              vs{" "}
              {match.teamBId ? (
                <Link className="hover:underline" href={`/teams/${match.teamBId}`}>
                  {match.teamBName}
                </Link>
              ) : (
                match.teamBName
              )}
            </h1>
            <p className="mt-1 text-sm text-white/70">
              {[
                match.venue || locationLabel(match.location),
                match.roundName,
                match.scheduledAt ? formatMatchWhen(match.scheduledAt) : "",
              ]
                .filter(Boolean)
                .join(" · ")}
              {match.tournamentId ? (
                <>
                  {" · "}
                  <Link className="underline-offset-2 hover:underline" href={`/tournaments/${match.tournamentId}`}>
                    Tournament
                  </Link>
                </>
              ) : null}
            </p>
          </div>
          <div className="flex gap-2">
            <FollowShare kind="match" id={match.id} title={match.title} path={`/matches/${match.id}`} />
          </div>
        </div>
        <div className="mt-6 grid gap-6 md:grid-cols-2">
          <div>
            <p className="text-5xl font-black">
              {overlay
                ? `${overlay.totalRuns}/${overlay.totalWickets}`
                : innings
                  ? `${innings.totalRuns}/${innings.totalWickets}`
                  : "—"}
            </p>
            <p className="mt-1 text-white/80">
              Overs{" "}
              {overlay
                ? formatOvers(overlay.legalBalls, overlay.ballsPerOver)
                : innings
                  ? formatOvers(innings.legalBalls, bpo)
                  : "0.0"}
              {overlay?.target ? ` · Target ${overlay.target}` : innings?.targetRuns ? ` · Target ${innings.targetRuns}` : ""}
            </p>
          </div>
          <div className="grid grid-cols-2 gap-3 text-sm">
            <div>
              <p className="text-white/60">Striker</p>
              <p className="font-semibold">
                {overlay?.strikerName || "—"} {overlay ? `${overlay.strikerRuns}(${overlay.strikerBalls})` : ""}
              </p>
            </div>
            <div>
              <p className="text-white/60">Non-striker</p>
              <p className="font-semibold">
                {overlay?.nonStrikerName || "—"}{" "}
                {overlay ? `${overlay.nonStrikerRuns}(${overlay.nonStrikerBalls})` : ""}
              </p>
            </div>
            <div>
              <p className="text-white/60">Bowler</p>
              <p className="font-semibold">
                {overlay?.bowlerName || "—"}{" "}
                {overlay ? `${overlay.bowlerWickets}/${overlay.bowlerRuns}` : ""}
              </p>
            </div>
            <div>
              <p className="text-white/60">Partnership</p>
              <p className="font-semibold">
                {innings ? `${innings.partnershipRuns} (${innings.partnershipBalls})` : "—"}
              </p>
            </div>
          </div>
        </div>
        {match.resultSummary ? <p className="mt-4 font-medium text-gold">{match.resultSummary}</p> : null}
        {match.matchHero?.playerName ? (
          <p className="mt-2 text-sm text-white/80">
            Match hero:{" "}
            {match.matchHero.playerId ? (
              <Link className="text-gold underline-offset-2 hover:underline" href={`/players/${match.matchHero.playerId}`}>
                {match.matchHero.playerName}
              </Link>
            ) : (
              match.matchHero.playerName
            )}
            {match.matchHero.reason ? ` — ${match.matchHero.reason}` : ""}
          </p>
        ) : null}
      </header>

      <div className={`grid gap-6 ${watchMode ? "lg:grid-cols-[1.4fr_1fr]" : ""}`}>
        {watchMode ? (
          <Card className="overflow-hidden p-0">
            {videoId ? (
              <iframe
                title="Watch live"
                className="aspect-video w-full"
                src={`https://www.youtube.com/embed/${videoId}?rel=0`}
                allowFullScreen
              />
            ) : (
              <EmptyState
                title="Stream not live"
                description="When the broadcaster starts, the YouTube or existing stream link appears here. Scoring and RTMP ingest stay on the mobile app."
              />
            )}
          </Card>
        ) : null}

        <div className="space-y-4">
          <nav className="flex flex-wrap gap-2" aria-label="Match sections">
            {(
              [
                "scorecard",
                "commentary",
                "stats",
                "wagon",
                "manhattan",
                "partnerships",
                "players",
                "highlights",
              ] as Tab[]
            ).map((item) => (
              <Button
                key={item}
                size="sm"
                variant={tab === item ? "default" : "outline"}
                onClick={() => setTab(item)}
              >
                {item}
              </Button>
            ))}
            <Button size="sm" variant="outline" asChild>
              <Link href={`/matches/${match.id}/watch`}>Watch</Link>
            </Button>
          </nav>

          {tab === "scorecard" ? <Scorecard match={match} /> : null}
          {tab === "commentary" ? <Commentary events={events} /> : null}
          {tab === "stats" ? <Stats innings={match.innings} events={events} /> : null}
          {tab === "wagon" ? <WagonWheel events={events} /> : null}
          {tab === "manhattan" ? (
            <Card className="p-4">
              <h3 className="mb-4 font-semibold">Manhattan</h3>
              {manhattan.length === 0 ? (
                <EmptyState title="No over data yet" />
              ) : (
                <div className="h-72">
                  <ResponsiveContainer width="100%" height="100%">
                    <BarChart data={manhattan}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="over" />
                      <YAxis />
                      <Tooltip />
                      <Bar dataKey="runs" fill="#1E88E5" />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              )}
            </Card>
          ) : null}
          {tab === "partnerships" ? <Partnerships match={match} /> : null}
          {tab === "players" ? <PlayersTab match={match} /> : null}
          {tab === "highlights" ? <HighlightsPanel events={events} highlights={highlights} /> : null}
          <FantasyLeagues matchId={match.id} />
        </div>
      </div>
    </div>
  );
}

function Scorecard({ match }: { match: Match }) {
  if (match.innings.length === 0) return <EmptyState title="Scorecard not available yet" />;
  return (
    <div className="space-y-6">
      {match.innings.map((inn) => (
        <Card key={inn.inningsNumber} className="overflow-x-auto p-0">
          <div className="border-b border-border p-4 font-semibold">
            Innings {inn.inningsNumber} · {inn.totalRuns}/{inn.totalWickets} ({formatOvers(inn.legalBalls, match.rules.ballsPerOver)}) · Extras {inn.extras}
          </div>
          <table className="w-full text-sm">
            <thead className="bg-muted/50 text-left">
              <tr>
                <th className="p-3">Batter</th>
                <th>R</th>
                <th>B</th>
                <th>4s</th>
                <th>6s</th>
                <th>SR</th>
              </tr>
            </thead>
            <tbody>
              {inn.batsmen.map((b) => (
                <tr key={b.playerId} className="border-t border-border">
                  <td className="p-3">
                    <div className="font-medium">
                      {b.playerId ? (
                        <Link className="hover:underline" href={`/players/${b.playerId}`}>
                          {b.playerName || b.playerId}
                        </Link>
                      ) : (
                        b.playerName || b.playerId
                      )}
                    </div>
                    <div className="text-xs text-muted-foreground">
                      {b.retiredHurt || b.status === "retired_hurt"
                        ? "Retired Hurt"
                        : b.status === "retired_out"
                          ? "Retired Out"
                        : b.isOut
                          ? b.dismissalInfo || "Out"
                          : "not out"}
                    </div>
                  </td>
                  <td>{b.runs}{b.retiredHurt ? "*" : ""}</td>
                  <td>{b.balls}</td>
                  <td>{b.fours}</td>
                  <td>{b.sixes}</td>
                  <td>{strikeRate(b.runs, b.balls)}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <table className="w-full text-sm">
            <thead className="bg-muted/50 text-left">
              <tr>
                <th className="p-3">Bowler</th>
                <th>O</th>
                <th>R</th>
                <th>W</th>
                <th>Wd</th>
                <th>Nb</th>
              </tr>
            </thead>
            <tbody>
              {inn.bowlers.map((b) => (
                <tr key={b.playerId} className="border-t border-border">
                  <td className="p-3 font-medium">
                    {b.playerId ? (
                      <Link className="hover:underline" href={`/players/${b.playerId}`}>
                        {b.playerName || b.playerId}
                      </Link>
                    ) : (
                      b.playerName || b.playerId
                    )}
                  </td>
                  <td>{formatOvers(b.oversBowledBalls, match.rules.ballsPerOver)}</td>
                  <td>{b.runsConceded}</td>
                  <td>{b.wickets}</td>
                  <td>{b.wides}</td>
                  <td>{b.noBalls}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {inn.fallOfWickets.length > 0 ? (
            <p className="p-4 text-sm text-muted-foreground">
              FOW: {inn.fallOfWickets.map((f) => `${f.wicketNumber}-${f.teamScore} (${f.batsmanName})`).join(", ")}
            </p>
          ) : null}
        </Card>
      ))}
    </div>
  );
}

function Commentary({ events }: { events: BallEvent[] }) {
  const [filter, setFilter] = useState<"all" | "wickets" | "boundaries" | "extras">("all");
  if (events.length === 0) return <EmptyState title="No commentary yet" />;
  const visible = events.filter((event) => {
    if (filter === "wickets") return event.isWicket;
    if (filter === "boundaries") return event.runs >= 4 && !event.isWicket;
    if (filter === "extras") return ["wide", "noBall", "bye", "legBye"].includes(event.eventType);
    return true;
  });
  return (
    <div>
      <div className="mb-3 flex flex-wrap gap-2">
        {(["all", "wickets", "boundaries", "extras"] as const).map((item) => (
          <button
            key={item}
            type="button"
            className={`rounded-full px-3 py-1 text-xs capitalize ${filter === item ? "bg-primary text-white" : "bg-muted"}`}
            onClick={() => setFilter(item)}
          >
            {item}
          </button>
        ))}
      </div>
      {visible.length === 0 ? (
        <EmptyState title="No balls in this filter" />
      ) : (
        <ol className="space-y-2">
          {[...visible].reverse().map((event) => (
            <li key={event.id} className="rounded-xl border border-border px-4 py-3 text-sm">
              <span className="font-semibold">
                {event.overNumber}.{event.ballInOver}
              </span>{" "}
              <span className="text-muted-foreground">{eventTypeLabel(event.eventType)}</span>
              {event.isFreeHit ? <Badge className="ml-2" variant="live">FH</Badge> : null}
              {event.isWicket ? <Badge className="ml-2" variant="live">Wicket</Badge> : null}
              <p className="mt-1">
                {event.commentary || `${event.runs} run${event.runs === 1 ? "" : "s"}`}
              </p>
            </li>
          ))}
        </ol>
      )}
    </div>
  );
}

function Stats({ innings, events }: { innings: Match["innings"]; events: BallEvent[] }) {
  const batting = innings.flatMap((inn) => inn.batsmen);
  const bowling = innings.flatMap((inn) => inn.bowlers);
  const topBat = [...batting].sort((a, b) => b.runs - a.runs)[0];
  const topBowl = [...bowling].sort((a, b) => b.wickets - a.wickets || a.runsConceded - b.runsConceded)[0];
  const extras = extrasFromEvents(events);
  return (
    <div className="grid gap-4 md:grid-cols-2">
      <Card className="p-5">
        <h3 className="font-semibold">Top batter</h3>
        <p className="mt-2 text-2xl font-bold">{topBat ? `${topBat.playerName} ${topBat.runs}` : "—"}</p>
      </Card>
      <Card className="p-5">
        <h3 className="font-semibold">Top bowler</h3>
        <p className="mt-2 text-2xl font-bold">
          {topBowl ? `${topBowl.playerName} ${topBowl.wickets}/${topBowl.runsConceded}` : "—"}
        </p>
      </Card>
      <Card className="p-5 md:col-span-2">
        <h3 className="font-semibold">Extras</h3>
        <p className="mt-2 text-sm">
          Wides {extras.wides} · No balls {extras.noBalls} · Byes {extras.byes} · Leg byes {extras.legByes}
        </p>
      </Card>
    </div>
  );
}

function WagonWheel({ events }: { events: BallEvent[] }) {
  const shots = events.filter((e) => e.wagonWheel?.x != null && e.wagonWheel?.y != null);
  if (shots.length === 0) return <EmptyState title="No wagon wheel data" description="Shot plots appear when scorers capture wagon wheel on mobile." />;
  return (
    <Card className="p-6">
      <svg viewBox="0 0 100 100" className="mx-auto h-80 w-80" role="img" aria-label="Wagon wheel">
        <circle cx="50" cy="50" r="48" fill="#0D47A1" stroke="#fff" />
        <circle cx="50" cy="50" r="8" fill="#c4a574" />
        {shots.map((shot) => (
          <circle
            key={shot.id}
            cx={shot.wagonWheel!.x}
            cy={shot.wagonWheel!.y}
            r={shot.runs >= 4 ? 2.4 : 1.4}
            fill={shot.runs >= 6 ? "#FFC107" : shot.runs >= 4 ? "#43A047" : "#fff"}
          />
        ))}
      </svg>
    </Card>
  );
}

function Partnerships({ match }: { match: Match }) {
  const rows = match.innings.flatMap((inn) => inn.partnerships);
  if (rows.length === 0) return <EmptyState title="No partnerships recorded" />;
  return (
    <Card className="overflow-x-auto p-0">
      <table className="w-full text-sm">
        <thead className="bg-muted/50 text-left">
          <tr>
            <th className="p-3">Batters</th>
            <th>Runs</th>
            <th>Balls</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((p, i) => (
            <tr key={`${p.batterAId}-${p.batterBId}-${i}`} className="border-t border-border">
              <td className="p-3">
                {p.batterAName} & {p.batterBName}
              </td>
              <td>{p.runs}</td>
              <td>{p.balls}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </Card>
  );
}

function PlayersTab({ match }: { match: Match }) {
  const names = new Map<string, string>();
  for (const inn of match.innings) {
    for (const b of inn.batsmen) names.set(b.playerId, b.playerName);
    for (const b of inn.bowlers) names.set(b.playerId, b.playerName);
  }
  if (names.size === 0) return <EmptyState title="Squad not published" />;
  return (
    <div className="grid gap-2 md:grid-cols-2">
      {[...names.entries()].map(([id, name]) => (
        <Link key={id} href={`/players/${id}`} className="rounded-xl border border-border px-4 py-3 hover:bg-muted">
          {name || id}
        </Link>
      ))}
    </div>
  );
}

function HighlightsPanel({
  events,
  highlights,
}: {
  events: BallEvent[];
  highlights: MatchHighlight[];
}) {
  const fromEvents = events.filter(
    (event) => event.isHighlight || event.isWicket || event.runs >= 4,
  );
  if (highlights.length === 0 && fromEvents.length === 0) {
    return (
      <EmptyState
        title="No highlights yet"
        description="Boundaries, wickets, and published highlight clips appear here."
      />
    );
  }
  return (
    <div className="space-y-3">
      {highlights.map((item) => (
        <Card key={item.id} className="p-4">
          <p className="text-xs uppercase text-muted-foreground">{item.tag || "Highlight"}</p>
          <p className="font-semibold">{item.title}</p>
          {item.mediaUrl ? (
            youtubeEmbedId(item.mediaUrl) ? (
              <iframe
                title={item.title}
                className="mt-3 aspect-video w-full rounded-xl"
                src={`https://www.youtube.com/embed/${youtubeEmbedId(item.mediaUrl)}?rel=0`}
                allowFullScreen
              />
            ) : /\.(mp4|webm|mov)(\?|$)/i.test(item.mediaUrl) ? (
              <video src={item.mediaUrl} controls className="mt-3 max-h-80 w-full rounded-xl bg-black" />
            ) : (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={item.mediaUrl} alt="" className="mt-3 max-h-80 w-full rounded-xl object-cover" />
            )
          ) : null}
        </Card>
      ))}
      {fromEvents.slice(-12).reverse().map((event) => (
        <Card key={event.id} className="p-4 text-sm">
          <p className="font-semibold">
            {event.overNumber}.{event.ballInOver} · {eventTypeLabel(event.eventType)}
          </p>
          <p className="text-muted-foreground">
            {event.commentary || `${event.runs} runs`}
          </p>
        </Card>
      ))}
    </div>
  );
}

function FantasyLeagues({ matchId }: { matchId: string }) {
  const [leagues, setLeagues] = useState<FantasyLeague[]>([]);
  useEffect(() => {
    listFantasyLeaguesForMatch(matchId).then(setLeagues).catch(() => setLeagues([]));
  }, [matchId]);
  if (!leagues.length) return null;
  return (
    <section className="mt-6">
      <h2 className="mb-3 text-lg font-bold">Fantasy leagues</h2>
      <div className="grid gap-3 md:grid-cols-2">
        {leagues.map((league) => (
          <Card key={league.id} className="p-4">
            <p className="font-semibold">{league.name}</p>
            <p className="text-sm text-muted-foreground">
              {league.status} · squad of {league.squadSize}
            </p>
          </Card>
        ))}
      </div>
      <div className="mt-3">
        <GetTheApp title="Pick your fantasy squad in the CrickFlow app" description="League play stays on mobile. Web only shows public leagues for this match." />
      </div>
    </section>
  );
}

export function MatchCentreSkeleton() {
  return (
    <div className="space-y-4">
      <div className="h-48 animate-pulse rounded-2xl bg-muted" />
      <div className="h-96 animate-pulse rounded-2xl bg-muted" />
    </div>
  );
}
