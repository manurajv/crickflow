"use client";

import { AppLink as Link } from "@/components/shared/app-link";
import { FormEvent, useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { useAuth } from "@/features/auth/auth-provider";
import {
  useReviewClubJoinRequest,
  useReviewSeriesApproval,
  useSeriesApprovalsAccess,
  useSeriesRegistrationIdentity,
} from "@/features/series/hooks";
import { usePathParam } from "@/lib/use-path-param";
import { EmptyState, ErrorState } from "@/components/shared/states";

function field(value: unknown) {
  const text = value == null ? "" : String(value).trim();
  return text;
}

function DocumentImage({ url, label }: { url?: string; label: string }) {
  const [status, setStatus] = useState<"loading" | "ok" | "error">(url ? "loading" : "error");
  const [open, setOpen] = useState(false);
  if (!url) {
    return (
      <div>
        <p className="mb-2 text-sm font-medium">{label}</p>
        <p className="text-sm text-muted-foreground">No document uploaded</p>
      </div>
    );
  }
  return (
    <div>
      <p className="mb-2 text-sm font-medium">{label}</p>
      <button type="button" className="block w-full overflow-hidden rounded-lg border" onClick={() => setOpen(true)}>
        {status === "error" ? (
          <div className="flex h-40 items-center justify-center p-3 text-sm text-muted-foreground">
            Could not load this document. Try again.
          </div>
        ) : (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={url}
            alt={label}
            className="h-48 w-full object-cover"
            onLoad={() => setStatus("ok")}
            onError={() => setStatus("error")}
          />
        )}
        {status === "loading" ? (
          <div className="flex h-40 items-center justify-center text-sm text-muted-foreground">Loading…</div>
        ) : null}
      </button>
      {open ? (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/90 p-4"
          onClick={() => setOpen(false)}
        >
          <div className="max-h-full max-w-full overflow-auto" onClick={(e) => e.stopPropagation()}>
            <p className="mb-2 text-sm text-white">{label} — pinch or scroll to zoom</p>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={url} alt={label} className="max-h-[85vh] max-w-[90vw] object-contain" />
            <button type="button" className="mt-3 text-sm text-white underline" onClick={() => setOpen(false)}>
              Close
            </button>
          </div>
        </div>
      ) : null}
    </div>
  );
}

export function JoinRequestDetailPage() {
  const seriesId = usePathParam("seriesId", 1);
  const approvalId = usePathParam("approvalId", 3);
  const { user } = useAuth();
  const access = useSeriesApprovalsAccess(seriesId, user?.uid);
  const identity = useSeriesRegistrationIdentity(seriesId);
  const orgReview = useReviewSeriesApproval(seriesId);
  const clubReview = useReviewClubJoinRequest(seriesId);
  const [reason, setReason] = useState("");
  const [message, setMessage] = useState("");

  useEffect(() => {
    if (!seriesId || !approvalId) return;
    void identity.mutateAsync({ approvalId }).catch(() => undefined);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [seriesId, approvalId]);

  const pub = (identity.data?.public ?? {}) as Record<string, unknown>;
  const ident = (identity.data?.identity ?? {}) as Record<string, unknown>;
  const media = (identity.data?.media ?? {}) as Record<string, unknown>;
  const request = (identity.data?.request ?? {}) as Record<string, unknown>;
  const clubId = field(request.clubId);
  const isClubAdmin = Boolean(clubId && access.data?.myAdminClubIds?.includes(clubId));
  const isOrgAdmin = Boolean(access.data?.canManage);
  const status = field(request.status) || field(pub.status) || "pending";
  const clubReviewStatus = field(request.clubReviewStatus);
  const targetType = field(request.targetType);
  const isAdd = targetType === "playerAdd" || targetType === "playerRegistration";
  const pending = status === "pending";
  const clubScope =
    pending && isClubAdmin && !isAdd && (!clubReviewStatus || clubReviewStatus === "pending");
  const orgScope =
    pending && isOrgAdmin && (isAdd || clubReviewStatus === "approved" || Boolean(access.data?.isSuperAdmin));
  const canAct = clubScope || orgScope;
  const addedBy = field(request.addedByName);

  async function onReview(event: FormEvent, decision: "approved" | "rejected") {
    event.preventDefault();
    if (decision === "rejected" && !reason.trim()) {
      setMessage("A reason is required to reject this request.");
      return;
    }
    try {
      if (clubScope) {
        await clubReview.mutateAsync({ approvalId, decision, reason: reason.trim() });
      } else {
        await orgReview.mutateAsync({ approvalId, decision, reason: reason.trim() });
      }
      setMessage(decision === "approved" ? "Request approved" : "Request rejected");
      await identity.mutateAsync({ approvalId });
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Could not review this request");
    }
  }

  const custom = pub.customFields && typeof pub.customFields === "object"
    ? Object.entries(pub.customFields as Record<string, unknown>)
    : [];

  if (!seriesId || !approvalId) return <p>Loading…</p>;
  if (identity.isError) {
    return (
      <ErrorState
        title="Could not load this request"
        description="You may not have access, or the request is no longer available."
      />
    );
  }

  return (
    <div className="space-y-6">
      <Link href={`/series/${seriesId}/approvals`} className="text-sm text-primary">
        Back to approvals
      </Link>
      <Card className="space-y-4 p-6">
        <div className="flex items-center gap-4">
          {field(media.profilePhotoUrl) ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={field(media.profilePhotoUrl)} alt="" className="h-16 w-16 rounded-full object-cover" />
          ) : (
            <div className="flex h-16 w-16 items-center justify-center rounded-full bg-muted text-xl">
              {field(pub.fullName).charAt(0) || "?"}
            </div>
          )}
          <div>
            <h1 className="text-2xl font-semibold">{field(pub.fullName) || "Player"}</h1>
            <p className="text-sm text-muted-foreground">{isAdd ? "Add player request" : "Join request"}</p>
            {field(pub.crickFlowPlayerId) ? (
              <p className="text-sm text-muted-foreground">CrickFlow ID: {field(pub.crickFlowPlayerId)}</p>
            ) : null}
          </div>
        </div>
        <div className="flex flex-wrap gap-2 text-sm">
          <span className="rounded-full border px-2 py-0.5">{status}</span>
          {clubReviewStatus ? (
            <span className="rounded-full border px-2 py-0.5">{clubReviewStatus}</span>
          ) : null}
        </div>
        {field(pub.teamName) ? <p><span className="font-medium">Team:</span> {field(pub.teamName)}</p> : null}
        {field(pub.orgName) ? <p><span className="font-medium">Organization:</span> {field(pub.orgName)}</p> : null}
        {addedBy ? <p><span className="font-medium">Added by:</span> {addedBy}</p> : null}
        {field(pub.submittedAt) || field(request.submittedAt) ? (
          <p>
            <span className="font-medium">Submitted:</span>{" "}
            {field(pub.submittedAt) || field(request.submittedAt)}
          </p>
        ) : null}
        {field(ident.nationalId) ? <p><span className="font-medium">National ID:</span> {field(ident.nationalId)}</p> : null}
        {field(ident.passportNumber) ? <p><span className="font-medium">Passport:</span> {field(ident.passportNumber)}</p> : null}
        {field(pub.phoneNumber) ? <p><span className="font-medium">Phone:</span> {field(pub.phoneNumber)}</p> : null}
        {field(pub.address) ? <p><span className="font-medium">Address:</span> {field(pub.address)}</p> : null}
        {field(pub.dateOfBirth) ? (
          <p><span className="font-medium">Date of birth:</span> {field(pub.dateOfBirth).split("T")[0]}</p>
        ) : null}
        {custom.map(([k, v]) =>
          field(v) ? (
            <p key={k}><span className="font-medium">{k}:</span> {field(v)}</p>
          ) : null,
        )}
        {status !== "pending" && field(request.reason) ? (
          <p><span className="font-medium">Decision reason:</span> {field(request.reason)}</p>
        ) : null}
        {identity.isPending && !identity.data ? <p>Loading documents…</p> : null}
        <DocumentImage url={field(media.nationalIdDocUrl) || undefined} label="National ID document" />
        <DocumentImage url={field(media.passportDocUrl) || undefined} label="Passport document" />
        {canAct ? (
          <form className="space-y-3 border-t pt-4">
            <label className="block text-sm">
              Reason (required to reject)
              <textarea
                className="mt-1 w-full rounded-md border p-2"
                value={reason}
                onChange={(e) => setReason(e.target.value)}
                rows={3}
              />
            </label>
            <div className="flex gap-3">
              <Button type="button" variant="outline" onClick={(e) => void onReview(e, "rejected")}>
                Reject
              </Button>
              <Button type="button" onClick={(e) => void onReview(e, "approved")}>
                Approve
              </Button>
            </div>
          </form>
        ) : !user ? (
          <EmptyState title="Sign in required" />
        ) : null}
        {message ? <p className="text-sm">{message}</p> : null}
      </Card>
    </div>
  );
}
