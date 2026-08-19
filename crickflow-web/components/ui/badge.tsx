import { cn } from "@/lib/utils";

export function Badge({
  className,
  variant = "default",
  ...props
}: React.HTMLAttributes<HTMLSpanElement> & {
  variant?: "default" | "live" | "upcoming" | "completed" | "outline" | "green";
}) {
  const styles = {
    default: "bg-primary/15 text-primary",
    live: "bg-live text-white",
    upcoming: "bg-primary/15 text-primary",
    completed: "bg-muted text-muted-foreground",
    outline: "border border-border text-foreground",
    green: "bg-cricket/15 text-cricket",
  } as const;
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full px-2.5 py-0.5 text-[11px] font-bold uppercase tracking-wide",
        styles[variant],
        className,
      )}
      {...props}
    />
  );
}
