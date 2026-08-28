"use client";

import { useTheme } from "next-themes";
import Link from "next/link";
import { useState } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input, Textarea } from "@/components/ui/input";
import { EmptyState } from "@/components/shared/states";
import { LocationOptIn } from "@/components/shared/location-opt-in";
import { PhotoPicker } from "@/components/shared/media";
import { useAuth } from "@/features/auth/auth-provider";
import { storageUploadHint, uploadUserProfilePhoto } from "@/lib/media-upload";
import { upsertUserProfile } from "@/repositories";
import type { UserProfile } from "@/types/models";
import type { User } from "firebase/auth";

export default function SettingsPage() {
  const { user, profile, loading, logout } = useAuth();
  const { theme, setTheme } = useTheme();

  if (loading) return <p>Loading…</p>;
  if (!user) {
    return <EmptyState title="Sign in to manage settings" action={<Link href="/login">Sign in</Link>} />;
  }

  return (
    <Card className="mx-auto max-w-xl space-y-6 p-6">
      <h1 className="text-3xl font-bold">Settings</h1>
      <section>
        <h2 className="font-semibold">Appearance</h2>
        <p className="mt-1 text-sm text-muted-foreground">CrickFlow light / dark tokens.</p>
        <div className="mt-3 flex gap-2">
          <Button variant={theme === "light" ? "default" : "outline"} onClick={() => setTheme("light")}>
            Light
          </Button>
          <Button variant={theme === "dark" ? "default" : "outline"} onClick={() => setTheme("dark")}>
            Dark
          </Button>
          <Button variant="outline" onClick={() => setTheme("system")}>
            System
          </Button>
        </div>
      </section>
      <section>
        <h2 className="font-semibold">Location</h2>
        <p className="mt-1 mb-3 text-sm text-muted-foreground">
          Optional. Used only when you choose nearby filters.
        </p>
        <LocationOptIn />
      </section>
      {profile ? <ProfileForm key={profile.id} user={user} profile={profile} /> : <p>Loading profile…</p>}
      <section>
        <h2 className="font-semibold">Account</h2>
        <Button className="mt-3" variant="outline" onClick={() => logout()}>
          Log out
        </Button>
      </section>
    </Card>
  );
}

function ProfileForm({ user, profile }: { user: User; profile: UserProfile | null }) {
  const { refreshProfile } = useAuth();
  const [name, setName] = useState(profile?.name ?? "");
  const [displayName, setDisplayName] = useState(profile?.displayName ?? "");
  const [bio, setBio] = useState(profile?.bio ?? "");
  const [photos, setPhotos] = useState<File[]>([]);
  const [saved, setSaved] = useState(false);
  const [uploading, setUploading] = useState(false);

  return (
    <form
      className="space-y-3"
      onSubmit={async (e) => {
        e.preventDefault();
        setUploading(true);
        try {
          let photoUrl = profile?.photoUrl;
          if (photos[0]) {
            photoUrl = await uploadUserProfilePhoto(user.uid, photos[0]);
          }
          await upsertUserProfile({
            id: user.uid,
            email: profile?.email ?? user.email ?? "",
            name,
            displayName,
            bio,
            photoUrl,
            role: profile?.role ?? "organizer",
            location: profile?.location,
          });
          await refreshProfile();
          setPhotos([]);
          setSaved(true);
        } catch (error) {
          toast.error(storageUploadHint(error));
        } finally {
          setUploading(false);
        }
      }}
    >
      <h2 className="font-semibold">Profile</h2>
      {profile?.photoUrl ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={profile.photoUrl} alt="" className="h-16 w-16 rounded-full object-cover" />
      ) : null}
      <PhotoPicker files={photos} onChange={setPhotos} max={1} label="Profile photo" />
      <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="Name" />
      <Input value={displayName} onChange={(e) => setDisplayName(e.target.value)} placeholder="Display name" />
      <Textarea value={bio} onChange={(e) => setBio(e.target.value)} placeholder="Bio" />
      <Button type="submit" disabled={uploading}>{uploading ? "Saving…" : "Save"}</Button>
      {saved ? <p className="text-sm text-cricket">Saved.</p> : null}
    </form>
  );
}
