import { cn } from "@/lib/utils";

export function Skeleton({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn("animate-pulse rounded-xl bg-muted", className)}
      {...props}
    />
  );
}

export function EmptyState({
  title,
  description,
  action,
  icon,
}: {
  title: string;
  description?: string;
  action?: React.ReactNode;
  icon?: React.ReactNode;
}) {
  return (
    <div className="flex flex-col items-center justify-center rounded-2xl border border-dashed border-border bg-card/50 px-6 py-16 text-center">
      {icon ? (
        <div className="mb-4 flex h-14 w-14 items-center justify-center rounded-full bg-accent text-primary">{icon}</div>
      ) : (
        <div className="mb-4 flex h-14 w-14 items-center justify-center rounded-full bg-accent text-2xl" aria-hidden>
          🏏
        </div>
      )}
      <h2 className="text-lg font-bold">{title}</h2>
      {description ? (
        <p className="mt-2 max-w-md text-sm text-muted-foreground">{description}</p>
      ) : null}
      {action ? <div className="mt-5">{action}</div> : null}
    </div>
  );
}

export function ErrorState({
  title = "Something went wrong",
  description,
  onRetry,
}: {
  title?: string;
  description?: string;
  onRetry?: () => void;
}) {
  return (
    <EmptyState
      title={title}
      description={description ?? "Please try again."}
      icon={<span aria-hidden>⚠</span>}
      action={
        onRetry ? (
          <button
            type="button"
            onClick={onRetry}
            className="rounded-xl bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
          >
            Retry
          </button>
        ) : null
      }
    />
  );
}
