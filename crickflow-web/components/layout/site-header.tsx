"use client";

import Image from "next/image";
import { AppLink as Link } from "@/components/shared/app-link";
import { PoweredByMavixas } from "@/components/shared/powered-by-mavixas";
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
import { PRIMARY_NAV, SECONDARY_NAV } from "@/lib/layout/site-nav";


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
      <div className="mx-auto flex h-16 max-w-7xl items-center gap-2 px-3 sm:gap-3 sm:px-4">
        <Link href="/" className="flex shrink-0 items-center gap-2 font-bold tracking-tight">
          <Image
            src={siteConfig.logoUrl}
            alt={siteConfig.name}
            width={36}
            height={36}
            className="h-9 w-9 rounded-lg bg-white"
            priority
          />
          {/* Wordmark shows beside the logo on tablet (nav is in the menu) and again at 2xl when there is room. */}
          <span className="hidden truncate sm:inline lg:hidden 2xl:inline">{siteConfig.name}</span>
        </Link>
        <nav className="hidden min-w-0 flex-1 items-center gap-0.5 overflow-hidden lg:flex" aria-label="Primary">
          {PRIMARY_NAV.map((item) => {
            const active = pathMatches(pathname, item.href);
            return (
              <Link
                key={item.href}
                href={item.href}
                className={cn(
                  "shrink-0 rounded-lg px-2 py-2 text-sm font-medium text-muted-foreground transition hover:bg-muted hover:text-foreground xl:px-2.5 2xl:px-3",
                  active && "bg-accent-soft text-[color:var(--nav-selected)] font-semibold dark:bg-accent-soft dark:text-[color:var(--nav-selected)]",
                )}
              >
                {item.label}
              </Link>
            );
          })}
          <details className="relative">
            <summary className="cursor-pointer list-none rounded-lg px-2 py-2 text-sm font-medium text-muted-foreground hover:bg-muted hover:text-foreground xl:px-2.5 2xl:px-3">
              More
            </summary>
            <div className="absolute left-0 top-full z-50 mt-1 min-w-[10rem] rounded-xl border border-border bg-card p-1 shadow-lg">
              {SECONDARY_NAV.map((item) => (
                <Link
                  key={item.href}
                  href={item.href}
                  className={cn(
                    "block rounded-lg px-3 py-2 text-sm hover:bg-muted",
                    pathMatches(pathname, item.href) && "font-semibold text-[color:var(--nav-selected)]",
                  )}
                >
                  {item.label}
                </Link>
              ))}
            </div>
          </details>
        </nav>
        <div className="ml-auto flex shrink-0 items-center gap-1.5">
          <Button
            variant="outline"
            className="hidden h-9 w-44 justify-start text-muted-foreground xl:flex xl:w-56"
            onClick={() => setSearchOpen(true)}
          >
            <Search className="h-4 w-4" />
            Search cricket…
            <kbd className="ml-auto rounded bg-muted px-1.5 py-0.5 text-[10px] font-medium">Ctrl K</kbd>
          </Button>
          <Button variant="ghost" size="icon" className="xl:hidden" onClick={() => setSearchOpen(true)} aria-label="Search">
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
          {[...PRIMARY_NAV, ...SECONDARY_NAV].map((item) => (
            <Link
              key={item.href}
              href={item.href}
              onClick={() => setMenuForPath(null)}
              className={cn(
                "rounded-lg px-3 py-2 text-sm hover:bg-muted",
                pathMatches(pathname, item.href) && "bg-accent-soft font-semibold text-[color:var(--nav-selected)]",
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
          <Link href="/help" onClick={() => setMenuForPath(null)} className="rounded-lg px-3 py-2 text-sm hover:bg-muted">
            CrickFlow Help
          </Link>
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
    { href: "/series", label: "Orgs" },
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
    { href: "/help", label: "CrickFlow Help" },
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
        <PoweredByMavixas className="mt-2" />
      </div>
    </footer>
  );
}
