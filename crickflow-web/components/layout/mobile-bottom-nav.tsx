"use client";

import { AppLink as Link } from "@/components/shared/app-link";
import { usePathname } from "next/navigation";
import {
  Home,
  Radio,
  Users,
  Compass,
  UserRound,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useAuth } from "@/features/auth/auth-provider";

const TABS = [
  { href: "/", label: "Home", icon: Home },
  { href: "/matches", label: "Matches", icon: Radio },
  { href: "/series", label: "Orgs", icon: Users },
  { href: "/discover", label: "Discover", icon: Compass },
  { href: "/profile", label: "Me", icon: UserRound, authHref: "/login" },
] as const;

function active(pathname: string, href: string) {
  const current = pathname.replace(/\/+$/, "") || "/";
  const target = href.replace(/\/+$/, "") || "/";
  if (target === "/") return current === "/" || current === "/home";
  return current === target || current.startsWith(`${target}/`);
}

/** Compact app-like bottom nav for small screens. */
export function MobileBottomNav() {
  const pathname = usePathname();
  const { user } = useAuth();

  return (
    <nav
      className="fixed inset-x-0 bottom-0 z-40 border-t border-border bg-chrome/95 pb-[env(safe-area-inset-bottom)] backdrop-blur-md lg:hidden"
      aria-label="Primary mobile"
    >
      <ul className="mx-auto grid max-w-lg grid-cols-5">
        {TABS.map((tab) => {
          const href =
            "authHref" in tab && !user ? (tab.authHref as string) : tab.href;
          const isActive = active(pathname, tab.href);
          const Icon = tab.icon;
          return (
            <li key={tab.href}>
              <Link
                href={href}
                className={cn(
                  "flex flex-col items-center gap-0.5 px-1 py-2 text-[10px] font-medium text-[color:var(--nav-unselected)] transition",
                  isActive && "text-[color:var(--nav-selected)]",
                )}
              >
                <Icon
                  className={cn("h-5 w-5", isActive && "stroke-[2.5]")}
                  aria-hidden
                />
                <span>{tab.label}</span>
              </Link>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
