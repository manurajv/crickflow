"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import type { User } from "firebase/auth";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { PhotoPicker } from "@/components/shared/media";
import { useAuth } from "@/features/auth/auth-provider";
import {
  BATTING_STYLES,
  BATTING_STYLE_LABELS,
  BOWLING_ARMS,
  BOWLING_ARM_LABELS,
  BOWLING_CATEGORIES,
  BOWLING_CATEGORY_LABELS,
  BOWLING_STYLE_LABELS,
  PLAYING_ROLES,
  PLAYING_ROLE_LABELS,
  bowlingStyleFromCategoryAndArm,
  spinStylesForArm,
  type BattingStyle,
  type BowlingArm,
  type BowlingCategory,
  type BowlingStyle,
  type PlayingRole,
} from "@/lib/cricket/player-profile";
import { storageUploadHint, uploadUserProfilePhoto } from "@/lib/media-upload";
import { completePlayerOnboarding } from "@/repositories";
import type { UserProfile } from "@/types/models";

const STEP_COUNT = 5;

const selectClass =
  "h-11 w-full rounded-xl border border-border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring";

export function PlayerOnboardingForm({
  user,
  profile,
}: {
  user: User;
  profile: UserProfile | null;
}) {
  const { refreshProfile } = useAuth();
  const router = useRouter();
  const [step, setStep] = useState(0);
  const [busy, setBusy] = useState(false);

  const [photos, setPhotos] = useState<File[]>([]);
  const [name, setName] = useState(profile?.name || user.displayName || "");
  const [displayName, setDisplayName] = useState(profile?.displayName || user.displayName || "");
  const [playingRole, setPlayingRole] = useState<PlayingRole | "">(
    (profile?.playingRole as PlayingRole | undefined) ?? "",
  );
  const [battingStyle, setBattingStyle] = useState<BattingStyle | "">(
    (profile?.battingStyle as BattingStyle | undefined) ?? "",
  );
  const [bowlingCategory, setBowlingCategory] = useState<BowlingCategory | "">("");
  const [bowlingArm, setBowlingArm] = useState<BowlingArm | "">("");
  const [bowlingStyle, setBowlingStyle] = useState<BowlingStyle | "">(
    (profile?.bowlingStyle as BowlingStyle | undefined) ?? "",
  );

  const photoPreview = useMemo(() => {
    if (photos[0]) return URL.createObjectURL(photos[0]);
    return profile?.photoUrl || user.photoURL || "";
  }, [photos, profile?.photoUrl, user.photoURL]);

  useEffect(() => {
    if (!photos[0] || typeof photoPreview !== "string" || !photoPreview.startsWith("blob:")) return;
    return () => URL.revokeObjectURL(photoPreview);
  }, [photos, photoPreview]);

  const progress = ((step + 1) / STEP_COUNT) * 100;

  function validateStep(): string | null {
    switch (step) {
      case 0:
        return null;
      case 1: {
        const trimmed = name.trim();
        if (trimmed.length < 2 || trimmed.length > 50) {
          return "Full name must be 2–50 characters";
        }
        return null;
      }
      case 2:
        return playingRole ? null : "Select your playing role";
      case 3:
        return battingStyle ? null : "Select your batting style";
      case 4:
        if (!bowlingCategory) return "Select bowling type";
        if (bowlingCategory === "doNotBowl") return null;
        if (bowlingCategory === "spin") {
          return bowlingStyle ? null : "Select your spin bowling style";
        }
        return bowlingArm ? null : "Select bowling arm";
      default:
        return null;
    }
  }

  function resolvedBowlingStyle(): BowlingStyle | null {
    if (!bowlingCategory) return null;
    if (bowlingCategory === "doNotBowl") return "doNotBowl";
    if (bowlingCategory === "spin") return bowlingStyle || null;
    if (!bowlingArm) return null;
    return bowlingStyleFromCategoryAndArm(bowlingCategory, bowlingArm);
  }

  async function finish() {
    const error = validateStep();
    if (error) {
      toast.error(error);
      return;
    }
    const resolvedBowling = resolvedBowlingStyle();
    if (!playingRole || !battingStyle || !resolvedBowling) {
      toast.error("Complete batting and bowling details before continuing");
      return;
    }

    setBusy(true);
    try {
      let photoUrl = profile?.photoUrl || user.photoURL || undefined;
      if (photos[0]) {
        photoUrl = await uploadUserProfilePhoto(user.uid, photos[0]);
      }

      await completePlayerOnboarding({
        id: user.uid,
        email: profile?.email ?? user.email ?? "",
        phoneNumber: profile?.phoneNumber ?? user.phoneNumber ?? undefined,
        name: name.trim(),
        displayName: displayName.trim() || name.trim(),
        photoUrl,
        role: profile?.role ?? "organizer",
        location: profile?.location ?? {
          country: "",
          stateProvince: "",
          district: "",
          city: "",
          placeName: "",
        },
        bio: profile?.bio ?? "",
        playingRole,
        battingStyle,
        bowlingStyle: resolvedBowling,
        playerId: profile?.playerId,
      });
      await refreshProfile();
      router.replace("/");
    } catch (err) {
      toast.error(storageUploadHint(err));
    } finally {
      setBusy(false);
    }
  }

  function next() {
    const error = validateStep();
    if (error) {
      toast.error(error);
      return;
    }
    if (step < STEP_COUNT - 1) {
      setStep((s) => s + 1);
      return;
    }
    void finish();
  }

  function back() {
    if (step === 0) return;
    setStep((s) => s - 1);
  }

  return (
    <Card className="mx-auto max-w-lg space-y-6 p-6 sm:p-8">
      <div>
        <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
          Step {step + 1} of {STEP_COUNT}
        </p>
        <div className="mt-2 h-2 overflow-hidden rounded-full bg-muted">
          <div className="h-full rounded-full bg-primary transition-all" style={{ width: `${progress}%` }} />
        </div>
      </div>

      {step === 0 ? (
        <section className="space-y-4 text-center">
          <h1 className="text-2xl font-bold">Profile photo</h1>
          <p className="text-sm text-muted-foreground">Optional — shown on your public player profile.</p>
          {photoPreview ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={photoPreview} alt="" className="mx-auto h-32 w-32 rounded-full object-cover" />
          ) : (
            <div className="mx-auto flex h-32 w-32 items-center justify-center rounded-full bg-muted text-muted-foreground">
              No photo
            </div>
          )}
          <PhotoPicker files={photos} onChange={setPhotos} max={1} label="Upload photo (optional)" />
        </section>
      ) : null}

      {step === 1 ? (
        <section className="space-y-4">
          <h1 className="text-2xl font-bold">Basic details</h1>
          <p className="text-sm text-muted-foreground">Tell us about yourself.</p>
          <Input
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Full name *"
            required
          />
          <Input
            value={displayName}
            onChange={(e) => setDisplayName(e.target.value)}
            placeholder="Display name (optional)"
          />
        </section>
      ) : null}

      {step === 2 ? (
        <section className="space-y-4">
          <h1 className="text-2xl font-bold">Playing role</h1>
          <p className="text-sm text-muted-foreground">How do you usually play?</p>
          <select
            className={selectClass}
            value={playingRole}
            onChange={(e) => setPlayingRole(e.target.value as PlayingRole)}
          >
            <option value="">Select role</option>
            {PLAYING_ROLES.map((role) => (
              <option key={role} value={role}>
                {PLAYING_ROLE_LABELS[role]}
              </option>
            ))}
          </select>
        </section>
      ) : null}

      {step === 3 ? (
        <section className="space-y-4">
          <h1 className="text-2xl font-bold">Batting style</h1>
          <p className="text-sm text-muted-foreground">Required for squad cards and discover.</p>
          <div className="grid gap-2">
            {BATTING_STYLES.map((style) => (
              <Button
                key={style}
                type="button"
                variant={battingStyle === style ? "default" : "outline"}
                className="justify-start"
                onClick={() => setBattingStyle(style)}
              >
                {BATTING_STYLE_LABELS[style]}
              </Button>
            ))}
          </div>
        </section>
      ) : null}

      {step === 4 ? (
        <section className="space-y-4">
          <h1 className="text-2xl font-bold">Bowling style</h1>
          <p className="text-sm text-muted-foreground">Required — choose &quot;Do Not Bowl&quot; if you don&apos;t bowl.</p>
          <select
            className={selectClass}
            value={bowlingCategory}
            onChange={(e) => {
              const value = e.target.value as BowlingCategory | "";
              setBowlingCategory(value);
              setBowlingArm("");
              setBowlingStyle("");
            }}
          >
            <option value="">Bowling type</option>
            {BOWLING_CATEGORIES.map((category) => (
              <option key={category} value={category}>
                {BOWLING_CATEGORY_LABELS[category]}
              </option>
            ))}
          </select>

          {bowlingCategory && bowlingCategory !== "doNotBowl" && bowlingCategory !== "spin" ? (
            <div className="grid gap-2 sm:grid-cols-2">
              {BOWLING_ARMS.map((arm) => (
                <Button
                  key={arm}
                  type="button"
                  variant={bowlingArm === arm ? "default" : "outline"}
                  onClick={() => setBowlingArm(arm)}
                >
                  {BOWLING_ARM_LABELS[arm]}
                </Button>
              ))}
            </div>
          ) : null}

          {bowlingCategory === "spin" ? (
            <>
              <div className="grid gap-2 sm:grid-cols-2">
                {BOWLING_ARMS.map((arm) => (
                  <Button
                    key={arm}
                    type="button"
                    variant={bowlingArm === arm ? "default" : "outline"}
                    onClick={() => {
                      setBowlingArm(arm);
                      setBowlingStyle("");
                    }}
                  >
                    {BOWLING_ARM_LABELS[arm]}
                  </Button>
                ))}
              </div>
              {bowlingArm ? (
                <div className="grid gap-2">
                  {spinStylesForArm(bowlingArm).map((style) => (
                    <Button
                      key={style}
                      type="button"
                      variant={bowlingStyle === style ? "default" : "outline"}
                      className="justify-start"
                      onClick={() => setBowlingStyle(style)}
                    >
                      {BOWLING_STYLE_LABELS[style]}
                    </Button>
                  ))}
                </div>
              ) : null}
            </>
          ) : null}
        </section>
      ) : null}

      <div className="flex gap-2">
        {step > 0 ? (
          <Button type="button" variant="outline" onClick={back} disabled={busy}>
            Back
          </Button>
        ) : null}
        <Button type="button" className="flex-1" onClick={next} disabled={busy}>
          {busy ? "Saving…" : step === STEP_COUNT - 1 ? "Finish" : step === 0 ? "Skip photo" : "Continue"}
        </Button>
      </div>
    </Card>
  );
}
