import { AppLink as Link } from "@/components/shared/app-link";
import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

export function PageHeader({
  title,
  description,
  actions,
  eyebrow,
  className,
}: {
  title: string;
  description?: ReactNode;
  actions?: ReactNode;
  eyebrow?: string;
  className?: string;
}) {
  return (
    <div className={cn("mb-8 flex flex-col gap-4 border-b border-border pb-6 sm:flex-row sm:items-end sm:justify-between", className)}>
      <div>
        {eyebrow ? (
          <p className="text-xs font-bold uppercase tracking-[0.18em] text-cricket">{eyebrow}</p>
        ) : null}
        <h1 className="text-3xl font-black tracking-tight text-foreground md:text-4xl">{title}</h1>
        {description ? <p className="mt-2 max-w-2xl text-sm text-muted-foreground md:text-base">{description}</p> : null}
      </div>
      {actions ? <div className="flex shrink-0 flex-wrap gap-2">{actions}</div> : null}
    </div>
  );
}

export function PageSection({
  title,
  href,
  hrefLabel = "View all",
  children,
  className,
}: {
  title: string;
  href?: string;
  hrefLabel?: string;
  children: ReactNode;
  className?: string;
}) {
  return (
    <section className={cn("space-y-4", className)}>
      <div className="flex items-end justify-between gap-3">
        <h2 className="text-xl font-bold tracking-tight md:text-2xl">{title}</h2>
        {href ? (
          <Link href={href} className="text-sm font-semibold text-primary hover:underline">
            {hrefLabel}
          </Link>
        ) : null}
      </div>
      {children}
    </section>
  );
}

export function ContentGrid({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={cn("grid gap-4 md:grid-cols-2 xl:grid-cols-3", className)}>{children}</div>;
}

export function LoadingGrid({ count = 6, className }: { count?: number; className?: string }) {
  return (
    <div className={cn("grid gap-4 md:grid-cols-2 xl:grid-cols-3", className)}>
      {Array.from({ length: count }).map((_, i) => (
        <div key={i} className="h-36 animate-pulse rounded-2xl bg-muted" />
      ))}
    </div>
  );
}

export function LoadingPage({ title = "Loading" }: { title?: string }) {
  return (
    <div className="space-y-6" aria-busy="true" aria-label={title}>
      <div className="h-10 w-56 animate-pulse rounded-xl bg-muted" />
      <div className="h-4 w-96 max-w-full animate-pulse rounded-lg bg-muted" />
      <LoadingGrid />
    </div>
  );
}
