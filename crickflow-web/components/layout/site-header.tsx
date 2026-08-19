"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { Menu, Search } from "lucide-react";
import { useEffect, useState } from "react";
import { siteConfig } from "@/config/site";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { useAuth } from "@/features/auth/auth-provider";
import { InboxBadges } from "@/features/layout/inbox-badges";
import { SearchDialog } from "@/features/search/search-dialog";

const NAV = [
  { href: "/", label: "Home" },
  { href: "/matches", label: "Matches" },
  { href: "/tournaments", label: "Tournaments" },
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
    <header className="sticky top-0 z-40 border-b border-border bg-chrome/95 backdrop-blur">
      <div className="mx-auto flex h-16 max-w-7xl items-center gap-3 px-4">
        <Link href="/" className="flex items-center gap-2 font-bold tracking-tight">
          <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary text-white">
            CF
          </span>
          <span className="hidden sm:inline">{siteConfig.name}</span>
        </Link>
        <nav className="hidden items-center gap-1 lg:flex" aria-label="Primary">
          {NAV.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "rounded-lg px-3 py-2 text-sm font-medium text-muted-foreground hover:bg-muted hover:text-foreground",
                pathMatches(pathname, item.href) && "bg-muted text-gold",
              )}
            >
              {item.label}
            </Link>
          ))}
        </nav>
        <div className="ml-auto flex items-center gap-2">
          <Button
            variant="outline"
            className="hidden h-9 w-56 justify-start text-muted-foreground md:flex"
            onClick={() => setSearchOpen(true)}
          >
            <Search className="h-4 w-4" />
            Search
            <kbd className="ml-auto text-[10px]">Ctrl K</kbd>
          </Button>
          <Button variant="ghost" size="icon" className="md:hidden" onClick={() => setSearchOpen(true)} aria-label="Search">
            <Search className="h-5 w-5" />
          </Button>
          {user ? (
            <>
              <InboxBadges />
              <Button variant="ghost" onClick={() => router.push("/profile")}>
                Profile
              </Button>
              <Button variant="outline" onClick={() => logout()}>
                Log out
              </Button>
            </>
          ) : (
            <Button onClick={() => router.push("/login")}>Sign in</Button>
          )}
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
                pathMatches(pathname, item.href) && "bg-muted text-gold",
              )}
            >
              {item.label}
            </Link>
          ))}
        </nav>
      ) : null}
      <SearchDialog open={searchOpen} onOpenChange={setSearchOpen} />
    </header>
  );
}

export function SiteFooter() {
  return (
    <footer className="mt-auto border-t border-border py-8 text-sm text-muted-foreground">
      <div className="mx-auto flex max-w-7xl flex-col gap-3 px-4 sm:flex-row sm:items-center sm:justify-between">
        <p suppressHydrationWarning>© {new Date().getFullYear()} CrickFlow · {siteConfig.tagline}</p>
        <div className="flex gap-4">
          <Link href="/legal/privacy">Privacy</Link>
          <Link href="/legal/terms">Terms</Link>
          <Link href="/grounds">Grounds</Link>
          <Link href="/statistics">Statistics</Link>
          <a href={siteConfig.playStoreUrl} target="_blank" rel="noreferrer">
            Get the app
          </a>
        </div>
      </div>
    </footer>
  );
}
