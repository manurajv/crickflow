"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { Menu, Search } from "lucide-react";
import { useEffect, useState } from "react";
import { siteConfig } from "@/config/site";
import { Button } from "@/components/ui/button";
import { ThemeToggle } from "@/components/layout/theme-toggle";
import { cn } from "@/lib/utils";
import { useAuth } from "@/features/auth/auth-provider";
import { InboxBadges } from "@/features/layout/inbox-badges";
import { SearchDialog } from "@/features/search/search-dialog";

const NAV = [
  { href: "/", label: "Home" },
  { href: "/matches", label: "Matches" },
  { href: "/tournaments", label: "Tournaments" },
  { href: "/series", label: "Series" },
  { href: "/teams", label: "Teams" },
  { href: "/players", label: "Players" },
  { href: "/community", label: "Community" },
  { href: "/discover", label: "Discover" },
  { href: "/rankings", label: "Rankings" },
];

function pathMatches(pathname: string, href: string) {
  const current = pathname.replace(/\/+$/, "") || "/";
  const target = href.replace(/\/+$/, "") || "/";
  if (target === "/") return current === "/";
  return current === target || current.startsWith(`${target}/`);
}

export function SiteHeader() {
  const pathname = usePathname();
  const router = useRouter();
  const { user, logout } = useAuth();
  const [menuForPath, setMenuForPath] = useState<string | null>(null);
  const [searchOpen, setSearchOpen] = useState(false);
  const open = menuForPath === pathname;

  useEffect(() => {
    function onKey(event: KeyboardEvent) {
      if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "k") {
        event.preventDefault();
        setSearchOpen(true);
      }
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  return (
    <header className="sticky top-0 z-40 border-b border-border bg-chrome/95 backdrop-blur-md">
      <div className="h-1 bg-gradient-to-r from-cricket via-primary to-gold" aria-hidden />
      <div className="mx-auto flex h-16 max-w-7xl items-center gap-3 px-4">
        <Link href="/" className="flex items-center gap-2.5 font-bold tracking-tight">
          <Image
            src={siteConfig.logoUrl}
            alt=""
            width={36}
            height={36}
            className="rounded-lg"
            priority
          />
          <span className="hidden sm:inline">{siteConfig.name}</span>
        </Link>
        <nav className="hidden items-center gap-0.5 lg:flex" aria-label="Primary">
          {NAV.map((item) => {
            const active = pathMatches(pathname, item.href);
            return (
              <Link
                key={item.href}
                href={item.href}
                className={cn(
                  "rounded-lg px-3 py-2 text-sm font-medium text-muted-foreground transition hover:bg-muted hover:text-foreground",
                  active && "bg-accent text-primary font-semibold",
                )}
              >
                {item.label}
              </Link>
            );
          })}
        </nav>
        <div className="ml-auto flex items-center gap-1.5">
          <Button
            variant="outline"
            className="hidden h-9 w-56 justify-start text-muted-foreground md:flex"
            onClick={() => setSearchOpen(true)}
          >
            <Search className="h-4 w-4" />
            Search cricket…
            <kbd className="ml-auto rounded bg-muted px-1.5 py-0.5 text-[10px] font-medium">Ctrl K</kbd>
          </Button>
          <Button variant="ghost" size="icon" className="md:hidden" onClick={() => setSearchOpen(true)} aria-label="Search">
            <Search className="h-5 w-5" />
          </Button>
          <ThemeToggle />
          {user ? (
            <>
              <InboxBadges />
              <Button variant="ghost" className="hidden sm:inline-flex" onClick={() => router.push("/profile")}>
                Profile
              </Button>
              <Button variant="outline" className="hidden sm:inline-flex" onClick={() => logout()}>
                Log out
              </Button>
            </>
          ) : (
            <Button onClick={() => router.push("/login")}>Sign in</Button>
          )}
          <Button variant="gold" size="sm" className="hidden xl:inline-flex" asChild>
            <a href={siteConfig.playStoreUrl} target="_blank" rel="noreferrer">
              Get app
            </a>
          </Button>
          <Button
            variant="ghost"
            size="icon"
            className="lg:hidden"
            onClick={() => setMenuForPath(open ? null : pathname)}
            aria-label="Menu"
            aria-expanded={open}
          >
            <Menu className="h-5 w-5" />
          </Button>
        </div>
      </div>
      {open ? (
        <nav className="grid gap-1 border-t border-border px-4 py-3 lg:hidden">
          {NAV.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              onClick={() => setMenuForPath(null)}
              className={cn(
                "rounded-lg px-3 py-2 text-sm hover:bg-muted",
                pathMatches(pathname, item.href) && "bg-accent font-semibold text-primary",
              )}
            >
              {item.label}
            </Link>
          ))}
          {user ? (
            <>
              <Link href="/profile" onClick={() => setMenuForPath(null)} className="rounded-lg px-3 py-2 text-sm hover:bg-muted">
                Profile
              </Link>
              <Link href="/settings" onClick={() => setMenuForPath(null)} className="rounded-lg px-3 py-2 text-sm hover:bg-muted">
                Settings
              </Link>
            </>
          ) : null}
          <a
            href={siteConfig.playStoreUrl}
            target="_blank"
            rel="noreferrer"
            className="rounded-lg px-3 py-2 text-sm font-semibold text-gold hover:bg-muted"
          >
            Get the app
          </a>
        </nav>
      ) : null}
      <SearchDialog open={searchOpen} onOpenChange={setSearchOpen} />
    </header>
  );
}

const FOOTER_LINKS = {
  Watch: [
    { href: "/matches?status=live", label: "Live scores" },
    { href: "/matches", label: "All matches" },
    { href: "/statistics", label: "Statistics" },
    { href: "/rankings", label: "Rankings" },
  ],
  Explore: [
    { href: "/series", label: "Series" },
    { href: "/tournaments", label: "Tournaments" },
    { href: "/teams", label: "Teams" },
    { href: "/players", label: "Players" },
    { href: "/grounds", label: "Grounds" },
    { href: "/discover", label: "Discover" },
    { href: "/community", label: "Community" },
  ],
  Account: [
    { href: "/login", label: "Sign in" },
    { href: "/register", label: "Player registration" },
    { href: "/profile", label: "Profile" },
    { href: "/settings", label: "Settings" },
  ],
  Legal: [
    { href: "/legal/privacy", label: "Privacy" },
    { href: "/legal/terms", label: "Terms" },
  ],
} as const;

export function SiteFooter() {
  return (
    <footer className="mt-auto border-t border-border bg-navy text-white/80">
      <div className="mx-auto grid max-w-7xl gap-8 px-4 py-12 sm:grid-cols-2 lg:grid-cols-5">
        <div className="lg:col-span-2">
          <div className="flex items-center gap-2.5">
            <Image src={siteConfig.logoUrl} alt="" width={32} height={32} className="rounded-lg" />
            <span className="text-lg font-bold text-white">{siteConfig.name}</span>
          </div>
          <p className="mt-3 max-w-sm text-sm">{siteConfig.description}</p>
          <a
            href={siteConfig.playStoreUrl}
            target="_blank"
            rel="noreferrer"
            className="mt-4 inline-flex rounded-xl bg-gold px-4 py-2 text-sm font-bold text-navy hover:bg-gold/90"
          >
            Download on Google Play
          </a>
        </div>
        {Object.entries(FOOTER_LINKS).map(([title, links]) => (
          <div key={title}>
            <h3 className="text-xs font-bold uppercase tracking-wider text-white/50">{title}</h3>
            <ul className="mt-3 space-y-2 text-sm">
              {links.map((link) => (
                <li key={link.href}>
                  <Link href={link.href} className="hover:text-white">
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>
      <div className="border-t border-white/10 py-4 text-center text-xs text-white/50">
        <p suppressHydrationWarning>© {new Date().getFullYear()} CrickFlow · {siteConfig.tagline}</p>
      </div>
    </footer>
  );
}
