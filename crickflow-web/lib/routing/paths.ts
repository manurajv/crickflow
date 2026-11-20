/** Normalize Next.js pathnames for trailingSlash: true exports. */
export function normalizePathname(pathname: string | null | undefined): string {
  if (!pathname) return "/";
  if (pathname === "/") return "/";
  return pathname.replace(/\/+$/, "") || "/";
}

export function pathsEqual(a: string, b: string): boolean {
  return normalizePathname(a) === normalizePathname(b);
}

export function pathStartsWith(pathname: string, prefix: string): boolean {
  const p = normalizePathname(pathname);
  const pre = normalizePathname(prefix);
  return p === pre || p.startsWith(`${pre}/`);
}
