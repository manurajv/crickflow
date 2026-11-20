"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { AppLink as Link } from "@/components/shared/app-link";
import { PhotoPicker } from "@/components/shared/media";
import { EmptyState } from "@/components/shared/states";
import { LoadingPage, PageHeader } from "@/components/shared/page-shell";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input, Textarea } from "@/components/ui/input";
import { useAuth } from "@/features/auth/auth-provider";
import { loginUrl } from "@/lib/auth/guest-access";
import { storageUploadHint, uploadUserProfilePhoto } from "@/lib/media-upload";
import {
  BATTING_STYLE_LABELS,
  BATTING_STYLES,
  BOWLING_STYLE_LABELS,
  BOWLING_STYLES,
  PLAYING_ROLE_LABELS,
  PLAYING_ROLES,
  labelForStoredBattingStyle,
  labelForStoredBowlingStyle,
} from "@/lib/cricket/player-profile";
import { displayCfPlayerId } from "@/lib/cricket/profile-display";
import { getPlayerByUserId, updatePlayerProfile, upsertUserProfile } from "@/repositories";
import { useQuery } from "@tanstack/react-query";

export default function EditProfilePage() {
  const { user, profile, loading, refreshProfile } = useAuth();
  const router = useRouter();
  const playerQuery = useQuery({
    queryKey: ["edit-player", user?.uid],
    queryFn: () => getPlayerByUserId(user!.uid),
    enabled: Boolean(user),
  });

  const [displayName, setDisplayName] = useState(profile?.displayName ?? profile?.name ?? "");
  const [bio, setBio] = useState(profile?.bio ?? "");
  const [playingRole, setPlayingRole] = useState(profile?.playingRole ?? "");
  const [battingStyle, setBattingStyle] = useState(
    labelForStoredBattingStyle(profile?.battingStyle) ?? profile?.battingStyle ?? "",
  );
  const [bowlingStyle, setBowlingStyle] = useState(
    labelForStoredBowlingStyle(profile?.bowlingStyle) ?? profile?.bowlingStyle ?? "",
  );
  const [phoneNumber, setPhoneNumber] = useState(profile?.phoneNumber ?? "");
  const [dateOfBirth, setDateOfBirth] = useState(toDateInput(profile?.dateOfBirth));
  const [photos, setPhotos] = useState<File[]>([]);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!profile) return;
    setDisplayName(profile.displayName || profile.name || "");
    setBio(profile.bio ?? "");
    setPlayingRole(profile.playingRole ?? "");
    setBattingStyle(labelForStoredBattingStyle(profile.battingStyle) ?? profile.battingStyle ?? "");
    setBowlingStyle(labelForStoredBowlingStyle(profile.bowlingStyle) ?? profile.bowlingStyle ?? "");
    setPhoneNumber(profile.phoneNumber ?? "");
    setDateOfBirth(toDateInput(profile.dateOfBirth));
  }, [profile]);

  if (loading) return <LoadingPage title="Loading profile" />;
  if (!user) {
    return (
      <EmptyState
        title="Sign in to edit your profile"
        action={<Link href={loginUrl("/profile/edit", "edit_profile")}>Sign in</Link>}
      />
    );
  }

  const cfId = displayCfPlayerId(playerQuery.data?.playerId || profile?.playerId);

  return (
    <div className="mx-auto max-w-xl space-y-6">
      <PageHeader
        title="Edit profile"
        eyebrow="Account"
        description="Update the photo, cricket details, and private contact fields that only you can see."
      />
      <Card className="space-y-4 p-6 shadow-sm">
        {cfId ? <p className="text-sm text-muted-foreground">CrickFlow ID: {cfId}</p> : null}
        {profile?.photoUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={profile.photoUrl} alt="" className="h-20 w-20 rounded-full object-cover" />
        ) : null}
        <PhotoPicker files={photos} onChange={setPhotos} max={1} label="Profile photo" />
        <label className="block space-y-1 text-sm font-medium">
          Display name
          <Input value={displayName} onChange={(e) => setDisplayName(e.target.value)} required />
        </label>
        <label className="block space-y-1 text-sm font-medium">
          Bio
          <Textarea value={bio} onChange={(e) => setBio(e.target.value)} placeholder="A short intro" />
        </label>
        <label className="block space-y-1 text-sm font-medium">
          Playing role
          <select
            className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm"
            value={playingRole}
            onChange={(e) => setPlayingRole(e.target.value)}
          >
            <option value="">Select a role</option>
            {PLAYING_ROLES.map((role) => (
              <option key={role} value={role}>
                {PLAYING_ROLE_LABELS[role]}
              </option>
            ))}
          </select>
        </label>
        <label className="block space-y-1 text-sm font-medium">
          Batting style
          <select
            className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm"
            value={battingStyle}
            onChange={(e) => setBattingStyle(e.target.value)}
          >
            <option value="">Select a style</option>
            {BATTING_STYLES.map((style) => (
              <option key={style} value={style}>
                {BATTING_STYLE_LABELS[style]}
              </option>
            ))}
          </select>
        </label>
        <label className="block space-y-1 text-sm font-medium">
          Bowling style
          <select
            className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm"
            value={bowlingStyle}
            onChange={(e) => setBowlingStyle(e.target.value)}
          >
            <option value="">Select a style</option>
            {BOWLING_STYLES.map((style) => (
              <option key={style} value={style}>
                {BOWLING_STYLE_LABELS[style]}
              </option>
            ))}
          </select>
        </label>
        <div className="rounded-xl border border-border bg-muted/40 p-4 space-y-3">
          <p className="text-sm font-semibold">Private details</p>
          <p className="text-xs text-muted-foreground">
            Email, phone, and date of birth are visible only to you — not on your public cricket profile.
          </p>
          <label className="block space-y-1 text-sm font-medium">
            Email
            <Input value={profile?.email || user.email || ""} readOnly />
          </label>
          <label className="block space-y-1 text-sm font-medium">
            Phone
            <Input value={phoneNumber} onChange={(e) => setPhoneNumber(e.target.value)} placeholder="Phone number" />
          </label>
          <label className="block space-y-1 text-sm font-medium">
            Date of birth
            <Input type="date" value={dateOfBirth} onChange={(e) => setDateOfBirth(e.target.value)} />
          </label>
        </div>
        <div className="flex gap-3">
          <Button
            disabled={saving || !displayName.trim()}
            onClick={async () => {
              setSaving(true);
              try {
                let photoUrl = profile?.photoUrl;
                if (photos[0]) {
                  photoUrl = await uploadUserProfilePhoto(user.uid, photos[0]);
                }
                await upsertUserProfile({
                  id: user.uid,
                  email: profile?.email ?? user.email ?? "",
                  name: displayName.trim(),
                  displayName: displayName.trim(),
                  bio,
                  photoUrl,
                  role: profile?.role ?? "player",
                  location: profile?.location,
                  playingRole: playingRole || undefined,
                  battingStyle: battingStyle || undefined,
                  bowlingStyle: bowlingStyle || undefined,
                  phoneNumber,
                  dateOfBirth,
                  playerId: profile?.playerId,
                });
                const linked = playerQuery.data;
                if (linked) {
                  await updatePlayerProfile(linked.id, {
                    name: displayName.trim(),
                    photoUrl,
                    role: playingRole || linked.role,
                    battingStyle: battingStyle || linked.battingStyle,
                    bowlingStyle: bowlingStyle || linked.bowlingStyle,
                  });
                }
                await refreshProfile();
                toast.success("Profile saved");
                router.push("/profile/");
              } catch (error) {
                toast.error(storageUploadHint(error));
              } finally {
                setSaving(false);
              }
            }}
          >
            {saving ? "Saving…" : "Save"}
          </Button>
          <Button variant="outline" asChild>
            <Link href="/profile">Cancel</Link>
          </Button>
        </div>
      </Card>
    </div>
  );
}

function toDateInput(value?: string | null): string {
  if (!value) return "";
  const raw = value.trim();
  if (/^\d{4}-\d{2}-\d{2}/.test(raw)) return raw.slice(0, 10);
  const date = new Date(raw);
  if (Number.isNaN(date.getTime())) return "";
  return date.toISOString().slice(0, 10);
}
