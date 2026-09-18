"use client";

import { AppLink as Link } from "@/components/shared/app-link";
import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import { doc, updateDoc } from "firebase/firestore";
import { EntityCard } from "@/components/shared/cards";
import { PageHeader, LoadingGrid } from "@/components/shared/page-shell";
import { EmptyState } from "@/components/shared/states";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { useAuth } from "@/features/auth/auth-provider";
import { useActiveSeries, useCreateSeries } from "@/features/series/hooks";
import { uploadSeriesCover, uploadSeriesLogo, storageUploadHint } from "@/lib/media-upload";
import { getDb } from "@/lib/firebase/client";
import { collections } from "@/config/site";

export default function SeriesPage() {
  const { data, isLoading, error } = useActiveSeries();
  const { user } = useAuth();
  const createSeries = useCreateSeries();
  const router = useRouter();
  const [showCreate, setShowCreate] = useState(false);

  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [rulesText, setRulesText] = useState("");
  const [kind, setKind] = useState("series");
  const [logoUrl, setLogoUrl] = useState("");
  const [coverImageUrl, setCoverImageUrl] = useState("");
  const [logoFile, setLogoFile] = useState<File | null>(null);
  const [coverFile, setCoverFile] = useState<File | null>(null);
  const [maxSquad, setMaxSquad] = useState(20);
  const [requireFullName, setRequireFullName] = useState(true);
  const [requirePlayerId, setRequirePlayerId] = useState(true);
  const [requireDob, setRequireDob] = useState(false);
  const [requireNationalId, setRequireNationalId] = useState(false);
  const [requirePassport, setRequirePassport] = useState(false);
  const [requirePhone, setRequirePhone] = useState(false);
  const [requireAddress, setRequireAddress] = useState(false);
  const [requirePhoto, setRequirePhoto] = useState(false);
  const [winPoints, setWinPoints] = useState(2);
  const [lossPoints, setLossPoints] = useState(0);
  const [tiePoints, setTiePoints] = useState(1);
  const [nrPoints, setNrPoints] = useState(1);
  const [useNrr, setUseNrr] = useState(true);

  async function onCreate(e: FormEvent) {
    e.preventDefault();
    const trimmedName = name.trim();
    if (trimmedName.length < 3 || trimmedName.length > 120) {
      window.alert("Name must be 3–120 characters.");
      return;
    }
    if (maxSquad < 1 || maxSquad > 50) {
      window.alert("Max players per club must be between 1 and 50.");
      return;
    }
    if (!requireFullName && !requirePlayerId) {
      window.alert("Require at least Full name or CrickFlow Player ID.");
      return;
    }
    const optionalUrl = (value: string) => {
      const v = value.trim();
      if (!v) return undefined;
      try {
        const u = new URL(v);
        if (u.protocol !== "http:" && u.protocol !== "https:") return null;
        return v;
      } catch {
        return null;
      }
    };
    const logo = optionalUrl(logoUrl);
    const cover = optionalUrl(coverImageUrl);
    if (logo === null || cover === null) {
      window.alert("Logo and cover must be valid http(s) URLs when provided.");
      return;
    }
    
    try {
      const result = await createSeries.mutateAsync({
        name: trimmedName,
        description: description.trim(),
        rulesText: rulesText.trim(),
        kind,
        displayName: user?.displayName || "",
        logoUrl: logo,
        coverImageUrl: cover,
        settings: {
          maxSquadSize: maxSquad,
          requireFullName,
          requireCrickFlowPlayerId: requirePlayerId,
          requireDateOfBirth: requireDob,
          requireNationalId,
          requirePassport,
          requirePhoneNumber: requirePhone,
          requireAddress,
          requireProfilePhoto: requirePhoto,
          rankingRules: {
            winPoints,
            lossPoints,
            tiePoints,
            noResultPoints: nrPoints,
            bonusPointsEnabled: false,
            useNetRunRate: useNrr,
            useRunDifference: false,
          },
        },
      });
      
      const seriesId = result.seriesId;
      if (!seriesId) {
        throw new Error("No series ID returned");
      }

      let mediaWarning = false;
      try {
        if (logoFile || coverFile) {
          const updates: Record<string, string> = {};
          if (logoFile && user?.uid) {
            const logoDownloadUrl = await uploadSeriesLogo(seriesId, user.uid, logoFile);
            updates.logoUrl = logoDownloadUrl;
          }
          if (coverFile && user?.uid) {
            const coverDownloadUrl = await uploadSeriesCover(seriesId, user.uid, coverFile);
            updates.coverImageUrl = coverDownloadUrl;
          }
          if (Object.keys(updates).length > 0) {
            await updateDoc(doc(getDb(), collections.series, seriesId), {
              ...updates,
              updatedAt: new Date().toISOString(),
            });
          }
        }
      } catch (err) {
        console.error("Image upload failed:", err);
        mediaWarning = true;
      }

      setShowCreate(false);
      if (mediaWarning) {
        window.alert(
          `${kind.charAt(0).toUpperCase() + kind.slice(1)} created. Logo/cover could not be uploaded — add them in settings.`
        );
      }
      if (seriesId) router.push(`/series/${seriesId}`);
    } catch (err) {
      console.error("Create series failed:", err);
      window.alert("Could not create. Sign in and check the form values.");
    }
  }

  return (
    <div>
      <PageHeader
        title="Series"
        eyebrow="Cricket organizations"
        description="Discover official leagues, associations, clubs, and their rankings."
        actions={
          user ? (
            <Button onClick={() => setShowCreate((v) => !v)}>
              {showCreate ? "Cancel" : "Create Series"}
            </Button>
          ) : null
        }
      />

      {showCreate && user ? (
        <Card className="mt-6 space-y-4 p-4">
          <div>
            <h2 className="text-lg font-bold">
              Create a {kind.charAt(0).toUpperCase() + kind.slice(1)}
            </h2>
            <p className="text-sm text-muted-foreground">
              Configure branding, registration requirements, squad limits, and ranking rules up front.
              You become the Super Admin.
            </p>
          </div>
          <form className="space-y-6" onSubmit={onCreate}>
            <section className="grid gap-3 md:grid-cols-2">
              <h3 className="md:col-span-2 text-sm font-semibold uppercase tracking-wide text-muted-foreground">
                Basics
              </h3>
              <input
                className="rounded-md border border-border bg-background px-3 py-2 md:col-span-2"
                placeholder={`${kind.charAt(0).toUpperCase() + kind.slice(1)} name`}
                value={name}
                onChange={(e) => setName(e.target.value)}
                required
                minLength={3}
                maxLength={120}
              />
              <select
                className="rounded-md border border-border bg-background px-3 py-2"
                value={kind}
                onChange={(e) => setKind(e.target.value)}
                required
              >
                <option value="series">Series</option>
                <option value="league">League</option>
                <option value="association">Association</option>
                <option value="federation">Federation</option>
                <option value="company">Company</option>
                <option value="cup">Cup</option>
                <option value="other">Other</option>
              </select>
              <div className="md:col-span-2">
                <label className="block text-sm font-medium mb-2">
                  Logo image
                </label>
                <input
                  type="file"
                  accept="image/*"
                  className="block w-full text-sm text-muted-foreground
                    file:mr-4 file:py-2 file:px-4 file:rounded-md
                    file:border-0 file:text-sm file:font-semibold
                    file:bg-primary file:text-primary-foreground
                    hover:file:bg-primary/90 file:cursor-pointer"
                  onChange={(e) => {
                    const file = e.target.files?.[0];
                    if (file) {
                      setLogoFile(file);
                      setLogoUrl("");
                    }
                  }}
                />
                {!logoFile && (
                  <input
                    className="mt-2 rounded-md border border-border bg-background px-3 py-2 w-full"
                    placeholder="Or enter logo image URL"
                    value={logoUrl}
                    onChange={(e) => {
                      setLogoUrl(e.target.value);
                      if (e.target.value) setLogoFile(null);
                    }}
                  />
                )}
                {logoFile && (
                  <p className="mt-1 text-xs text-muted-foreground">
                    Selected: {logoFile.name}
                  </p>
                )}
              </div>
              <div className="md:col-span-2">
                <label className="block text-sm font-medium mb-2">
                  Cover image
                </label>
                <input
                  type="file"
                  accept="image/*"
                  className="block w-full text-sm text-muted-foreground
                    file:mr-4 file:py-2 file:px-4 file:rounded-md
                    file:border-0 file:text-sm file:font-semibold
                    file:bg-primary file:text-primary-foreground
                    hover:file:bg-primary/90 file:cursor-pointer"
                  onChange={(e) => {
                    const file = e.target.files?.[0];
                    if (file) {
                      setCoverFile(file);
                      setCoverImageUrl("");
                    }
                  }}
                />
                {!coverFile && (
                  <input
                    className="mt-2 rounded-md border border-border bg-background px-3 py-2 w-full"
                    placeholder="Or enter cover image URL"
                    value={coverImageUrl}
                    onChange={(e) => {
                      setCoverImageUrl(e.target.value);
                      if (e.target.value) setCoverFile(null);
                    }}
                  />
                )}
                {coverFile && (
                  <p className="mt-1 text-xs text-muted-foreground">
                    Selected: {coverFile.name}
                  </p>
                )}
              </div>
              <textarea
                className="rounded-md border border-border bg-background px-3 py-2 md:col-span-2"
                placeholder="Description"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                rows={3}
                maxLength={2000}
              />
              <textarea
                className="rounded-md border border-border bg-background px-3 py-2 md:col-span-2"
                placeholder="Rules / playing conditions"
                value={rulesText}
                onChange={(e) => setRulesText(e.target.value)}
                rows={4}
                maxLength={10000}
              />
            </section>

            <section className="space-y-3">
              <h3 className="text-sm font-semibold uppercase tracking-wide text-muted-foreground">
                Squad
              </h3>
              <label className="flex items-center gap-3 text-sm">
                Max players per club
                <input
                  type="number"
                  min={1}
                  max={50}
                  className="w-24 rounded-md border border-border bg-background px-3 py-2"
                  value={maxSquad}
                  onChange={(e) => setMaxSquad(Number(e.target.value) || 20)}
                />
              </label>
            </section>

            <section className="space-y-2">
              <h3 className="text-sm font-semibold uppercase tracking-wide text-muted-foreground">
                Registration requirements
              </h3>
              <div className="grid gap-2 sm:grid-cols-2">
                {[
                  ["Full name", requireFullName, setRequireFullName],
                  ["CrickFlow Player ID", requirePlayerId, setRequirePlayerId],
                  ["Date of birth", requireDob, setRequireDob],
                  ["National ID (private)", requireNationalId, setRequireNationalId],
                  ["Passport (private)", requirePassport, setRequirePassport],
                  ["Phone number", requirePhone, setRequirePhone],
                  ["Address", requireAddress, setRequireAddress],
                  ["Profile photo", requirePhoto, setRequirePhoto],
                ].map(([label, value, setter]) => (
                  <label key={String(label)} className="flex items-center gap-2 text-sm">
                    <input
                      type="checkbox"
                      checked={value as boolean}
                      onChange={(e) =>
                        (setter as (v: boolean) => void)(e.target.checked)
                      }
                    />
                    {label as string}
                  </label>
                ))}
              </div>
            </section>

            <section className="grid gap-3 sm:grid-cols-2 md:grid-cols-4">
              <h3 className="sm:col-span-2 md:col-span-4 text-sm font-semibold uppercase tracking-wide text-muted-foreground">
                Club ranking points
              </h3>
              {[
                ["Win", winPoints, setWinPoints],
                ["Loss", lossPoints, setLossPoints],
                ["Tie", tiePoints, setTiePoints],
                ["No result", nrPoints, setNrPoints],
              ].map(([label, value, setter]) => (
                <label key={String(label)} className="text-sm">
                  {label as string}
                  <input
                    type="number"
                    min={0}
                    className="mt-1 block w-full rounded-md border border-border bg-background px-3 py-2"
                    value={value as number}
                    onChange={(e) =>
                      (setter as (v: number) => void)(Number(e.target.value) || 0)
                    }
                  />
                </label>
              ))}
              <label className="flex items-center gap-2 text-sm sm:col-span-2 md:col-span-4">
                <input
                  type="checkbox"
                  checked={useNrr}
                  onChange={(e) => setUseNrr(e.target.checked)}
                />
                Use net run rate
              </label>
            </section>

            <Button type="submit" disabled={createSeries.isPending}>
              {createSeries.isPending
                ? "Creating…"
                : `Create ${kind.charAt(0).toUpperCase() + kind.slice(1)}`}
            </Button>
            {createSeries.isError ? (
              <p className="text-sm text-destructive">
                Could not create. Sign in and check the form values.
              </p>
            ) : null}
          </form>
        </Card>
      ) : null}

      {isLoading ? (
        <LoadingGrid count={6} className="mt-8 md:grid-cols-2" />
      ) : error ? (
        <div className="mt-8">
          <EmptyState title="Series could not be loaded" />
        </div>
      ) : !data?.length ? (
        <div className="mt-8">
          <EmptyState title="No active series yet" />
          {user ? (
            <p className="mt-3 text-center text-sm text-muted-foreground">
              <button
                type="button"
                className="text-primary underline"
                onClick={() => setShowCreate(true)}
              >
                Create the first Series
              </button>
            </p>
          ) : (
            <p className="mt-3 text-center text-sm text-muted-foreground">
              <Link href="/login" className="text-primary underline">
                Sign in
              </Link>{" "}
              to create a Series.
            </p>
          )}
        </div>
      ) : (
        <div className="mt-6 grid gap-4 md:grid-cols-2">
          {data.map((series) => (
            <EntityCard
              key={series.id}
              href={`/series/${series.id}`}
              title={series.name}
              subtitle={
                series.description ||
                `${series.clubCount} clubs · ${series.playerCount} players`
              }
              image={series.coverImageUrl || series.logoUrl}
              meta={`${series.kind.charAt(0).toUpperCase()}${series.kind.slice(1)} · ${series.status}`}
            />
          ))}
        </div>
      )}
    </div>
  );
}
