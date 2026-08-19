import type { MetadataRoute } from "next";
import { siteConfig } from "@/config/site";
import { listMatches, listPlayers, listTeams, listTournaments } from "@/repositories";
import { isFirebaseConfigured } from "@/lib/firebase/client";

export const dynamic = "force-static";

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const staticRoutes = [
    "",
    "/matches",
    "/tournaments",
    "/teams",
    "/players",
    "/grounds",
    "/community",
    "/discover",
    "/rankings",
    "/statistics",
  ].map((route) => ({
    url: `${siteConfig.url}${route}`,
    lastModified: new Date(),
    changeFrequency: "hourly" as const,
    priority: route === "" ? 1 : 0.7,
  }));

  if (!isFirebaseConfigured()) return staticRoutes;

  try {
    const [matches, players, teams, tournaments] = await Promise.all([
      listMatches({ take: 40 }),
      listPlayers(40),
      listTeams(40),
      listTournaments(40),
    ]);
    return [
      ...staticRoutes,
      ...matches.map((m) => ({
        url: `${siteConfig.url}/matches/${m.id}`,
        lastModified: m.completedAt ?? m.startedAt ?? new Date(),
        changeFrequency: "hourly" as const,
        priority: 0.8,
      })),
      ...players.map((p) => ({
        url: `${siteConfig.url}/players/${p.id}`,
        lastModified: new Date(),
        changeFrequency: "weekly" as const,
        priority: 0.6,
      })),
      ...teams.map((t) => ({
        url: `${siteConfig.url}/teams/${t.id}`,
        lastModified: new Date(),
        changeFrequency: "weekly" as const,
        priority: 0.6,
      })),
      ...tournaments.map((t) => ({
        url: `${siteConfig.url}/tournaments/${t.id}`,
        lastModified: new Date(),
        changeFrequency: "daily" as const,
        priority: 0.7,
      })),
    ];
  } catch {
    return staticRoutes;
  }
}
