"use client";

import { AppLink as Link } from "@/components/shared/app-link";
import { FormEvent, useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/shared/states";
import { useAuth } from "@/features/auth/auth-provider";
import {
  useSeriesDetail,
  useUpdateSeriesCompetitionPolicy,
  useUpdateSeriesSettings,
} from "@/features/series/hooks";
import { usePathParam } from "@/lib/use-path-param";
import { loginUrl } from "@/lib/auth/guest-access";
import {
  orgCompetitionPolicyFromMap,
  orgCompetitionPolicyToMap,
  proposeAccessLabel,
  type OrgCompetitionPolicy,
  type OrgProposeAccess,
} from "@/lib/cricket/org-competition-access";
import type { SeriesDetailData } from "@/features/series/types";

export function SeriesSettingsPage() {
  const seriesId = usePathParam("seriesId", 1);
  const { user } = useAuth();
  const { data, isLoading } = useSeriesDetail(seriesId, user?.uid);

  if (!seriesId || isLoading) return <p>Loading…</p>;
  if (!user) {
    return (
      <EmptyState
        title="Sign in required"
        action={<Link href={loginUrl(`/series/${seriesId}/settings`, "org_manage")}>Sign in</Link>}
      />
    );
  }
  if (!data?.isSuperAdmin && !data?.canManage) {
    return <EmptyState title="Admin access required" />;
  }
  if (!data) return <EmptyState title="Organization not found" />;

  const initialMax = data.series.settings.maxSquadSize || 20;
  const initialPolicy = orgCompetitionPolicyFromMap(data.series.competitionPolicy);

  return (
    <SettingsForm
      key={`${seriesId}-${initialMax}-${JSON.stringify(initialPolicy)}`}
      seriesId={seriesId}
      data={data}
      initialMax={initialMax}
      initialPolicy={initialPolicy}
    />
  );
}

function SettingsForm({
  seriesId,
  data,
  initialMax,
  initialPolicy,
}: {
  seriesId: string;
  data: SeriesDetailData;
  initialMax: number;
  initialPolicy: OrgCompetitionPolicy;
}) {
  const updateSettings = useUpdateSeriesSettings(seriesId);
  const updatePolicy = useUpdateSeriesCompetitionPolicy(seriesId);
  const [maxSquad, setMaxSquad] = useState(initialMax);
  const [policy, setPolicy] = useState(initialPolicy);
  const [baseline, setBaseline] = useState({ maxSquad: initialMax, policy: initialPolicy });
  const [saving, setSaving] = useState(false);

  const dirty =
    maxSquad !== baseline.maxSquad ||
    JSON.stringify(policy) !== JSON.stringify(baseline.policy);

  useEffect(() => {
    const onBeforeUnload = (e: BeforeUnloadEvent) => {
      if (!dirty) return;
      e.preventDefault();
      e.returnValue = "";
    };
    window.addEventListener("beforeunload", onBeforeUnload);
    return () => window.removeEventListener("beforeunload", onBeforeUnload);
  }, [dirty]);

  async function onSave(e?: FormEvent) {
    e?.preventDefault();
    if (!dirty) return;
    setSaving(true);
    try {
      if (maxSquad !== baseline.maxSquad) {
        await updateSettings.mutateAsync({
          ...data.series.settings,
          maxSquadSize: maxSquad,
        });
      }
      if (JSON.stringify(policy) !== JSON.stringify(baseline.policy)) {
        await updatePolicy.mutateAsync(orgCompetitionPolicyToMap(policy));
      }
      setBaseline({ maxSquad, policy });
    } finally {
      setSaving(false);
    }
  }

  function setAccess(key: "matchProposeAccess" | "tournamentProposeAccess", v: OrgProposeAccess) {
    setPolicy((p) => ({ ...p, [key]: v }));
  }

  return (
    <div className="space-y-4 pb-28">
      <div className="flex items-center gap-3">
        <Link
          href={`/series/${seriesId}?tab=overview`}
          className="text-sm text-primary"
          onClick={(e) => {
            if (dirty && !window.confirm("You have unsaved changes. Leave anyway?")) {
              e.preventDefault();
            }
          }}
        >
          ← Overview
        </Link>
        <h1 className="text-2xl font-bold">Settings</h1>
      </div>

      <Card className="space-y-3 p-4">
        <h2 className="font-semibold">Squad</h2>
        <label className="block text-sm">
          Max squad size
          <input
            type="number"
            min={1}
            max={50}
            className="mt-1 block w-28 rounded-md border border-border bg-background px-3 py-2"
            value={maxSquad}
            onChange={(e) => setMaxSquad(Number(e.target.value) || 20)}
          />
        </label>
      </Card>

      <Card className="space-y-3 p-4">
        <h2 className="font-semibold">Permissions</h2>
        <p className="text-sm text-muted-foreground">
          Same competitionPolicy as the CrickFlow app.
        </p>
        {(
          [
            ["matchProposeAccess", "Who can request matches"],
            ["tournamentProposeAccess", "Who can request tournaments"],
          ] as const
        ).map(([key, label]) => (
          <label key={key} className="block text-sm">
            {label}
            <select
              className="mt-1 block w-full max-w-md rounded-md border border-border bg-background px-3 py-2"
              value={policy[key]}
              onChange={(e) => setAccess(key, e.target.value as OrgProposeAccess)}
            >
              {(["admins", "teamAdmins", "everyone"] as const).map((v) => (
                <option key={v} value={v}>
                  {proposeAccessLabel(v)}
                </option>
              ))}
            </select>
          </label>
        ))}
        {(
          [
            ["matchTeamAdminsNeedApproval", "Match requests from team admins need approval"],
            ["matchPlayersNeedApproval", "Match requests from players need approval"],
            ["tournamentTeamAdminsNeedApproval", "Tournament requests from team admins need approval"],
            ["tournamentPlayersNeedApproval", "Tournament requests from players need approval"],
            ["allowWalkIns", "Allow walk-in players"],
          ] as const
        ).map(([key, label]) => (
          <label key={key} className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={Boolean(policy[key])}
              onChange={(e) => setPolicy((p) => ({ ...p, [key]: e.target.checked }))}
            />
            {label}
          </label>
        ))}
      </Card>

      <div className="fixed inset-x-0 bottom-16 z-30 flex justify-center px-4 lg:bottom-6">
        <Button
          className="shadow-lg"
          disabled={!dirty || saving}
          onClick={() => onSave()}
        >
          {saving ? "Saving…" : "Save settings"}
        </Button>
      </div>
    </div>
  );
}
