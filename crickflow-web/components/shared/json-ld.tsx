import { siteConfig } from "@/config/site";

export function JsonLd({ data }: { data: Record<string, unknown> }) {
  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(data) }}
    />
  );
}

export function sportsEventLd(options: {
  name: string;
  path: string;
  startDate?: Date | null;
  location?: string;
  homeTeam?: string;
  awayTeam?: string;
}) {
  return {
    "@context": "https://schema.org",
    "@type": "SportsEvent",
    name: options.name,
    url: `${siteConfig.url}${options.path}`,
    startDate: options.startDate?.toISOString(),
    location: options.location
      ? { "@type": "Place", name: options.location }
      : undefined,
    competitor: [options.homeTeam, options.awayTeam]
      .filter(Boolean)
      .map((name) => ({ "@type": "SportsTeam", name })),
  };
}

export function personLd(options: { name: string; path: string; image?: string; role?: string }) {
  return {
    "@context": "https://schema.org",
    "@type": "Person",
    name: options.name,
    url: `${siteConfig.url}${options.path}`,
    image: options.image,
    jobTitle: options.role,
  };
}

export function sportsTeamLd(options: { name: string; path: string; image?: string; location?: string }) {
  return {
    "@context": "https://schema.org",
    "@type": "SportsTeam",
    name: options.name,
    url: `${siteConfig.url}${options.path}`,
    logo: options.image,
    location: options.location,
    sport: "Cricket",
  };
}
