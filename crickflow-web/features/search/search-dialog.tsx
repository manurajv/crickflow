"use client";

import { useQuery } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { Input } from "@/components/ui/input";
import { searchScore } from "@/lib/utils";
import {
  listCommunityPosts,
  listDerivedGrounds,
  listMatches,
  listOpportunities,
  listPlayers,
  listTeams,
  listTournaments,
} from "@/repositories";

const CATEGORIES = ["all", "players", "teams", "matches", "tournaments", "posts", "discover", "grounds"] as const;

export function SearchPanel({
  onSelect,
  autoFocus = false,
}: {
  onSelect?: () => void;
  autoFocus?: boolean;
}) {
  const router = useRouter();
  const [q, setQ] = useState("");
  const [cat, setCat] = useState<(typeof CATEGORIES)[number]>("all");

  const players = useQuery({ queryKey: ["search-players"], queryFn: () => listPlayers(80) });
  const teams = useQuery({ queryKey: ["search-teams"], queryFn: () => listTeams(80) });
  const matches = useQuery({ queryKey: ["search-matches"], queryFn: () => listMatches({ take: 80 }) });
  const tournaments = useQuery({
    queryKey: ["search-tournaments"],
    queryFn: () => listTournaments(80),
  });
  const posts = useQuery({
    queryKey: ["search-posts"],
    queryFn: () => listCommunityPosts({ take: 40 }),
  });
  const listings = useQuery({
    queryKey: ["search-discover"],
    queryFn: () => listOpportunities({ take: 40 }),
  });
  const grounds = useQuery({
    queryKey: ["search-grounds"],
    queryFn: () => listDerivedGrounds(),
  });

  const results = useMemo(() => {
    const query = q.trim();
    if (query.length < 2) return [];
    const rows: { href: string; title: string; subtitle: string; score: number }[] = [];
    if (cat === "all" || cat === "players") {
      for (const p of players.data ?? []) {
        const score = searchScore(`${p.name} ${p.playerId ?? ""}`, query);
        if (score) rows.push({ href: `/players/${p.id}`, title: p.name, subtitle: "Player", score });
      }
    }
    if (cat === "all" || cat === "teams") {
      for (const t of teams.data ?? []) {
        const score = searchScore(t.name, query);
        if (score) rows.push({ href: `/teams/${t.id}`, title: t.name, subtitle: "Team", score });
      }
    }
    if (cat === "all" || cat === "matches") {
      for (const m of matches.data ?? []) {
        const score = searchScore(`${m.title} ${m.teamAName} ${m.teamBName}`, query);
        if (score)
          rows.push({
            href: `/matches/${m.id}`,
            title: m.title || `${m.teamAName} vs ${m.teamBName}`,
            subtitle: "Match",
            score,
          });
      }
    }
    if (cat === "all" || cat === "tournaments") {
      for (const t of tournaments.data ?? []) {
        const score = searchScore(t.name, query);
        if (score) rows.push({ href: `/tournaments/${t.id}`, title: t.name, subtitle: "Tournament", score });
      }
    }
    if (cat === "all" || cat === "posts") {
      for (const p of posts.data ?? []) {
        const score = searchScore(`${p.title} ${p.body}`, query);
        if (score) rows.push({ href: `/community/${p.id}`, title: p.title || p.body.slice(0, 60), subtitle: "Post", score });
      }
    }
    if (cat === "all" || cat === "discover") {
      for (const p of listings.data ?? []) {
        const score = searchScore(`${p.title} ${p.description}`, query);
        if (score) rows.push({ href: `/discover/${p.id}`, title: p.title || p.description.slice(0, 60), subtitle: "Discover", score });
      }
    }
    if (cat === "all" || cat === "grounds") {
      for (const g of grounds.data ?? []) {
        const score = searchScore(`${g.name} ${g.location.city} ${g.location.placeName}`, query);
        if (score) rows.push({ href: `/grounds/${g.id}`, title: g.name, subtitle: "Ground", score });
      }
    }
    return rows.sort((a, b) => b.score - a.score).slice(0, 12);
  }, [q, cat, players.data, teams.data, matches.data, tournaments.data, posts.data, listings.data, grounds.data]);

  return (
    <>
      <Input
        autoFocus={autoFocus}
        placeholder="Search players, teams, matches, grounds…"
        value={q}
        onChange={(e) => setQ(e.target.value)}
        aria-label="Search query"
      />
      <div className="mt-3 flex flex-wrap gap-2">
        {CATEGORIES.map((item) => (
          <button
            key={item}
            type="button"
            onClick={() => setCat(item)}
            className={`rounded-full px-3 py-1 text-xs font-semibold ${cat === item ? "bg-primary text-white" : "bg-muted"}`}
          >
            {item}
          </button>
        ))}
      </div>
      <ul className="mt-3 max-h-80 overflow-auto">
        {results.map((row) => (
          <li key={row.href}>
            <button
              type="button"
              className="flex w-full items-center justify-between rounded-xl px-3 py-2 text-left hover:bg-muted"
              onClick={() => {
                onSelect?.();
                router.push(row.href);
              }}
            >
              <span className="font-medium">{row.title}</span>
              <span className="text-xs text-muted-foreground">{row.subtitle}</span>
            </button>
          </li>
        ))}
        {q.trim().length >= 2 && results.length === 0 ? (
          <li className="px-3 py-6 text-center text-sm text-muted-foreground">No results</li>
        ) : null}
      </ul>
    </>
  );
}

export function SearchDialog({
  open,
  onOpenChange,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  useEffect(() => {
    if (!open) return;
    function onKey(event: KeyboardEvent) {
      if (event.key === "Escape") onOpenChange(false);
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, onOpenChange]);

  if (!open) return null;

  return (
    <div
      className="fixed inset-0 z-50 bg-black/50 p-4"
      role="dialog"
      aria-modal="true"
      aria-label="Search CrickFlow"
      onClick={() => onOpenChange(false)}
    >
      <div
        className="mx-auto mt-20 max-w-xl rounded-2xl border border-border bg-card p-4 shadow-xl"
        onClick={(event) => event.stopPropagation()}
      >
        <SearchPanel autoFocus onSelect={() => onOpenChange(false)} />
        <button
          type="button"
          className="mt-2 w-full rounded-xl py-2 text-sm text-muted-foreground"
          onClick={() => onOpenChange(false)}
        >
          Close
        </button>
      </div>
    </div>
  );
}
