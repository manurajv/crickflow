export const REPORT_REASONS = [
  { id: "spam", label: "Spam" },
  { id: "harassment", label: "Harassment" },
  { id: "misleading", label: "Misleading" },
  { id: "inappropriate", label: "Inappropriate" },
  { id: "other", label: "Other" },
] as const;

export function reportReasonValue(id: string, details?: string) {
  const trimmed = details?.trim() ?? "";
  const label = REPORT_REASONS.find((item) => item.id === id)?.label ?? "Other";
  return trimmed ? `${label}: ${trimmed}` : label;
}
