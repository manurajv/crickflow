import type { AnchorHTMLAttributes, ReactNode } from "react";
import Link from "next/link";
import { cn } from "@/lib/utils";

const STATIC_PREFIXES = [
  "/home",
  "/matches",
  "/players",
  "/teams",
  "/tournaments",
  "/series",
  "/community",
  "/discover",
  "/grounds",
  "/chat",
  "/profile",
  "/settings",
  "/login",
  "/register",
  "/search",
  "/notifications",
  "/rankings",
  "/statistics",
  "/unauthorized",
  "/legal",
  "/my-cricket",
  "/my-cricket-profile",
];

function withTrailingSlash(href: string): string {
  if (!href) return "/";
  if (href.startsWith("http") || href.startsWith("mailto:") || href.startsWith("#")) return href;
  const hashIndex = href.indexOf("#");
  const queryIndex = href.indexOf("?");
  let path = href;
  let suffix = "";
  if (hashIndex >= 0) {
    suffix = href.slice(hashIndex);
    path = href.slice(0, hashIndex);
  }
  if (queryIndex >= 0 && (hashIndex < 0 || queryIndex < hashIndex)) {
    const q = path.indexOf("?");
    suffix = path.slice(q) + suffix;
    path = path.slice(0, q);
  }
  if (!path.endsWith("/")) path = `${path}/`;
  return `${path}${suffix}`;
}

function isStaticAppPath(href: string): boolean {
  if (href.startsWith("http") || href.startsWith("mailto:") || href.startsWith("#")) return true;
  const path = href.split("?")[0].split("#")[0].replace(/\/$/, "") || "/";
  if (path === "/") return true;
  return STATIC_PREFIXES.some((prefix) => path === prefix);
}

/**
 * Next `output: "export"` only prebuilds `[param]=_`. Client <Link> to a real
 * id hits NotFound. Dynamic entity URLs use a full navigation so Firebase
 * Hosting can rewrite to the `_` shell.
 */
export function AppLink({
  href,
  className,
  children,
  ...rest
}: { href: string; children: ReactNode; className?: string } & Omit<
  AnchorHTMLAttributes<HTMLAnchorElement>,
  "href"
>) {
  const normalized = withTrailingSlash(href);
  if (isStaticAppPath(href)) {
    return (
      <Link href={normalized} className={className} {...rest}>
        {children}
      </Link>
    );
  }
  return (
    <a href={normalized} className={cn(className)} {...rest}>
      {children}
    </a>
  );
}
