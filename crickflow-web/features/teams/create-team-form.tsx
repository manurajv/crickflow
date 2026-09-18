"use client";

import { useState, FormEvent } from "react";
import { useRouter } from "next/navigation";
import { doc, setDoc, runTransaction, serverTimestamp } from "firebase/firestore";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { useAuth } from "@/features/auth/auth-provider";
import { getDb } from "@/lib/firebase/client";
import { uploadTeamLogo, storageUploadHint } from "@/lib/media-upload";
import { collections } from "@/config/site";
import { PhotoPicker } from "@/components/shared/media";
import type { LocationData } from "@/types/models";

export function CreateTeamForm({ onClose }: { onClose?: () => void }) {
  const { user, profile } = useAuth();
  const router = useRouter();
  const [name, setName] = useState("");
  const [logoFile, setLogoFile] = useState<File | null>(null);
  const [country, setCountry] = useState(profile?.location?.country || "Sri Lanka");
  const [stateProvince, setStateProvince] = useState(profile?.location?.stateProvince || "");
  const [city, setCity] = useState(profile?.location?.city || "");
  const [creating, setCreating] = useState(false);

  const onSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!user || !profile) {
      toast.error("Sign in to create a team");
      return;
    }
    if (!name.trim()) {
      toast.error("Team name is required");
      return;
    }
    if (!city.trim()) {
      toast.error("City is required");
      return;
    }

    setCreating(true);
    try {
      // Allocate team code
      const db = getDb();
      const teamId = `${Date.now()}_${Math.random().toString(36).substring(2, 11)}`;
      
      const teamCode = await runTransaction(db, async (tx) => {
        const counterRef = doc(db, "app_meta", "cf_team_ids");
        const snap = await tx.get(counterRef);
        const last = (snap.data()?.lastNumber as number) ?? 0;
        const next = last + 1;
        tx.set(counterRef, { lastNumber: next, updatedAt: new Date().toISOString() }, { merge: true });
        return `TM${String(next).padStart(6, "0")}`;
      });

      const location: LocationData = {
        country,
        stateProvince,
        district: "",
        city,
        placeName: "",
      };

      // Upload logo if provided
      let logoUrl: string | undefined;
      if (logoFile) {
        try {
          logoUrl = await uploadTeamLogo(teamId, user.uid, logoFile);
        } catch (error) {
          toast.warning(storageUploadHint(error));
        }
      }

      // Create team
      const teamData = {
        id: teamId,
        name: name.trim(),
        teamCode,
        logoUrl: logoUrl || null,
        teamProfileImageUrl: logoUrl || null,
        captainId: profile.playerId || null,
        viceCaptainId: null,
        coachName: null,
        contactNumber: null,
        playerIds: profile.playerId ? [profile.playerId] : [],
        memberCount: profile.playerId ? 1 : 0,
        location,
        stats: {
          matchesPlayed: 0,
          matchesWon: 0,
          matchesLost: 0,
          matchesTied: 0,
          points: 0,
          netRunRate: 0,
          totalRunsScored: 0,
          totalWicketsTaken: 0,
          totalWicketsLost: 0,
        },
        badgeIds: [],
        createdBy: user.uid,
        createdAt: serverTimestamp(),
      };

      await setDoc(doc(db, collections.teams, teamId), teamData);

      toast.success(`${name} created · Team ID ${teamCode}`);
      onClose?.();
      router.push(`/teams/${teamId}`);
    } catch (error) {
      toast.error(`Could not create team: ${error instanceof Error ? error.message : String(error)}`);
    } finally {
      setCreating(false);
    }
  };

  return (
    <Card className="p-6">
      <h2 className="text-xl font-bold">Create a team</h2>
      <form className="mt-4 space-y-4" onSubmit={onSubmit}>
        <div>
          <label className="block text-sm font-medium mb-1">Team name *</label>
          <Input
            placeholder="Team name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            required
          />
        </div>

        <div>
          <label className="block text-sm font-medium mb-1">Team logo (optional)</label>
          <PhotoPicker
            files={logoFile ? [logoFile] : []}
            onChange={(files) => setLogoFile(files[0] || null)}
            maxFiles={1}
          />
          <p className="mt-1 text-xs text-muted-foreground">Square logo recommended (1:1 aspect ratio)</p>
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

        <div className="flex gap-2">
          {onClose && (
            <Button type="button" variant="outline" onClick={onClose} disabled={creating}>
              Cancel
            </Button>
          )}
          <Button type="submit" disabled={creating} className="flex-1">
            {creating ? "Creating…" : "Create team"}
          </Button>
        </div>
      </form>
    </Card>
  );
}
