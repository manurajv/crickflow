import Link from "next/link";
import { cn } from "@/lib/utils";

export function FilterChip({
  href,
  active,
  live,
  onClick,
  children,
}: {
  href?: string;
  active: boolean;
  live?: boolean;
  onClick?: () => void;
  children: string;
}) {
  const className = cn(
    "rounded-full px-3.5 py-1.5 text-sm font-medium transition",
    active && live && "bg-live text-white shadow-sm",
    active && !live && "bg-primary text-primary-foreground shadow-sm",
    !active && "bg-muted text-muted-foreground hover:bg-muted/80",
  );

  if (href) {
    return (
      <Link className={className} href={href}>
        {children}
      </Link>
    );
  }

  return (
    <button type="button" className={className} onClick={onClick}>
      {children}
    </button>
  );
}
