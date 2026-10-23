import Image from "next/image";
import { AppLink as Link } from "@/components/shared/app-link";
import type { ReactNode } from "react";
import { siteConfig } from "@/config/site";

export function AuthShell({
  title,
  subtitle,
  children,
}: {
  title: string;
  subtitle?: string;
  children: ReactNode;
}) {
  return (
    <div className="mx-auto grid max-w-5xl gap-8 lg:grid-cols-[1fr_420px] lg:items-start">
      <section className="hidden overflow-hidden rounded-3xl bg-scoreboard bg-pitch-stripes px-8 py-12 text-white lg:block">
        <Image src={siteConfig.logoUrl} alt="" width={56} height={56} className="rounded-xl" />
        <p className="mt-6 text-xs font-bold uppercase tracking-[0.2em] text-gold">Official cricket platform</p>
        <h1 className="mt-4 text-4xl font-black leading-tight tracking-tight">
          Score. Stream. Connect.
        </h1>
        <p className="mt-4 max-w-md text-base text-white/85">
          Follow live matches, register as a player, join teams, and discover cricket opportunities near you — synced with the CrickFlow mobile app.
        </p>
        <ul className="mt-8 space-y-3 text-sm text-white/90">
          <li className="flex gap-2">
            <span className="text-gold">●</span> Real-time scores and ball-by-ball commentary
          </li>
          <li className="flex gap-2">
            <span className="text-gold">●</span> Player profiles, rankings, and statistics
          </li>
          <li className="flex gap-2">
            <span className="text-gold">●</span> Community posts and discover listings
          </li>
        </ul>
        <Link href="/" className="mt-10 inline-block text-sm font-semibold text-gold hover:underline">
          Browse without signing in →
        </Link>
      </section>
      <div>
        <div className="mb-6 lg:hidden">
          <Link href="/" className="inline-flex items-center gap-2 text-sm font-semibold text-muted-foreground">
            <Image src={siteConfig.logoUrl} alt="" width={28} height={28} className="rounded-md" />
            Back to {siteConfig.name}
          </Link>
        </div>
        <div className="rounded-3xl border border-border bg-card p-8 shadow-sm">
          <h1 className="text-2xl font-black tracking-tight">{title}</h1>
          {subtitle ? <p className="mt-2 text-sm text-muted-foreground">{subtitle}</p> : null}
          <div className="mt-6">{children}</div>
        </div>
      </div>
    </div>
  );
}
