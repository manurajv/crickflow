"use client";

import { useState, FormEvent } from "react";
import { useRouter } from "next/navigation";
import { doc, setDoc, serverTimestamp } from "firebase/firestore";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input, Textarea } from "@/components/ui/input";
import { useAuth } from "@/features/auth/auth-provider";
import { getDb } from "@/lib/firebase/client";
import { uploadTournamentBanner, storageUploadHint } from "@/lib/media-upload";
import { collections } from "@/config/site";
import { PhotoPicker } from "@/components/shared/media";
import type { LocationData } from "@/types/models";

const FORMATS = [
  { value: "league", label: "League" },
  { value: "knockout", label: "Knockout" },
  { value: "leagueKnockout", label: "League + Knockout" },
  { value: "custom", label: "Custom" },
];

export function CreateTournamentForm({ onClose }: { onClose?: () => void }) {
  const { user, profile } = useAuth();
  const router = useRouter();
  const [name, setName] = useState("");
  const [format, setFormat] = useState("league");
  const [bannerFile, setBannerFile] = useState<File | null>(null);
  const [country, setCountry] = useState(profile?.location?.country || "Sri Lanka");
  const [stateProvince, setStateProvince] = useState(profile?.location?.stateProvince || "");
  const [city, setCity] = useState(profile?.location?.city || "");
  const [grounds, setGrounds] = useState("");
  const [organizerName, setOrganizerName] = useState(profile?.displayName || "");
  const [creating, setCreating] = useState(false);

  const onSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!user || !profile) {
      toast.error("Sign in to create a tournament");
      return;
    }
    if (!name.trim()) {
      toast.error("Tournament name is required");
      return;
    }
    if (!city.trim()) {
      toast.error("City is required");
      return;
    }

    setCreating(true);
    try {
      const db = getDb();
      const tournamentId = `${Date.now()}_${Math.random().toString(36).substring(2, 11)}`;

      const location: LocationData = {
        country,
        stateProvince,
        district: "",
        city,
        placeName: "",
      };

      // Upload banner if provided
      let bannerUrl: string | undefined;
      if (bannerFile) {
        try {
          bannerUrl = await uploadTournamentBanner(tournamentId, user.uid, bannerFile);
        } catch (error) {
          toast.warning(storageUploadHint(error));
        }
      }

      const groundList = grounds.split(',').map(g => g.trim()).filter(g => g);

      // Create tournament
      const tournamentData = {
        id: tournamentId,
        name: name.trim(),
        format,
        status: "upcoming",
        teamIds: [],
        matchIds: [],
        pointsTable: [],
        bracketRounds: [],
        location,
        bannerUrl: bannerUrl || null,
        thumbnailUrl: bannerUrl || null,
        grounds: groundList,
        organizerName: organizerName.trim() || profile.displayName,
        createdBy: user.uid,
        startDate: null,
        endDate: null,
        createdAt: serverTimestamp(),
      };

      await setDoc(doc(db, collections.tournaments, tournamentId), tournamentData);

      toast.success(`${name} created`);
      onClose?.();
      router.push(`/tournaments/${tournamentId}`);
    } catch (error) {
      toast.error(`Could not create tournament: ${error instanceof Error ? error.message : String(error)}`);
    } finally {
      setCreating(false);
    }
  };

  return (
    <Card className="p-6">
      <h2 className="text-xl font-bold">Create a tournament</h2>
      <form className="mt-4 space-y-4" onSubmit={onSubmit}>
        <div>
          <label className="block text-sm font-medium mb-1">Tournament name *</label>
          <Input
            placeholder="Tournament name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            required
          />
        </div>

        <div>
          <label className="block text-sm font-medium mb-1">Format</label>
          <select
            className="h-10 w-full rounded-xl border border-input bg-background px-3 text-sm"
            value={format}
            onChange={(e) => setFormat(e.target.value)}
          >
            {FORMATS.map((f) => (
              <option key={f.value} value={f.value}>
                {f.label}
              </option>
            ))}
          </select>
        </div>

        <div>
          <label className="block text-sm font-medium mb-1">Banner image (optional)</label>
          <PhotoPicker
            files={bannerFile ? [bannerFile] : []}
            onChange={(files) => setBannerFile(files[0] || null)}
            max={1}
          />
          <p className="mt-1 text-xs text-muted-foreground">Wide banner recommended (16:9 aspect ratio)</p>
        </div>

        <div>
          <label className="block text-sm font-medium mb-1">Organizer name</label>
          <Input
            placeholder="Organizer name"
            value={organizerName}
            onChange={(e) => setOrganizerName(e.target.value)}
          />
        </div>

        <div>
          <label className="block text-sm font-medium mb-1">Country</label>
          <Input
            placeholder="Country"
            value={country}
            onChange={(e) => setCountry(e.target.value)}
          />
        </div>

        <div>
          <label className="block text-sm font-medium mb-1">State / Province</label>
          <Input
            placeholder="State or Province"
            value={stateProvince}
            onChange={(e) => setStateProvince(e.target.value)}
          />
        </div>

        <div>
          <label className="block text-sm font-medium mb-1">City *</label>
          <Input
            placeholder="City"
            value={city}
            onChange={(e) => setCity(e.target.value)}
            required
          />
        </div>

        <div>
          <label className="block text-sm font-medium mb-1">Grounds (comma-separated)</label>
          <Textarea
            placeholder="Ground 1, Ground 2, Ground 3"
            value={grounds}
            onChange={(e) => setGrounds(e.target.value)}
            rows={2}
          />
        </div>

        <div className="flex gap-2">
          {onClose && (
            <Button type="button" variant="outline" onClick={onClose} disabled={creating}>
              Cancel
            </Button>
          )}
          <Button type="submit" disabled={creating} className="flex-1">
            {creating ? "Creating…" : "Create tournament"}
          </Button>
        </div>
      </form>
    </Card>
  );
}
