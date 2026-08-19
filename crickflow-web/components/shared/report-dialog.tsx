"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/input";
import { REPORT_REASONS, reportReasonValue } from "@/lib/report";

export function ReportDialog({
  open,
  title,
  onClose,
  onSubmit,
}: {
  open: boolean;
  title: string;
  onClose: () => void;
  onSubmit: (reason: string) => Promise<void> | void;
}) {
  const [reasonId, setReasonId] = useState("spam");
  const [details, setDetails] = useState("");
  const [busy, setBusy] = useState(false);
  if (!open) return null;
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="w-full max-w-md rounded-2xl border bg-background p-5 shadow-lg">
        <h2 className="text-lg font-semibold">{title}</h2>
        <div className="mt-3 flex flex-wrap gap-2">
          {REPORT_REASONS.map((item) => (
            <button
              key={item.id}
              type="button"
              className={`rounded-full px-3 py-1 text-xs ${reasonId === item.id ? "bg-primary text-white" : "bg-muted"}`}
              onClick={() => setReasonId(item.id)}
            >
              {item.label}
            </button>
          ))}
        </div>
        <Textarea
          className="mt-3"
          value={details}
          onChange={(e) => setDetails(e.target.value)}
          placeholder="Optional details"
        />
        <div className="mt-4 flex justify-end gap-2">
          <Button variant="outline" onClick={onClose} disabled={busy}>
            Cancel
          </Button>
          <Button
            disabled={busy}
            onClick={async () => {
              setBusy(true);
              try {
                await onSubmit(reportReasonValue(reasonId, details));
                setDetails("");
                onClose();
              } finally {
                setBusy(false);
              }
            }}
          >
            {busy ? "Sending…" : "Report"}
          </Button>
        </div>
      </div>
    </div>
  );
}
