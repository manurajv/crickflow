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
import {
  COMMON_COUNTRIES,
  PLAYER_GENDERS,
  PLAYER_GENDER_LABELS,
  PHONE_DIAL_CODES,
  dialCodeForCountry,
  phoneNumberHint,
  takePendingNext,
  type PlayerGender,
} from "@/lib/cricket/onboarding-options";
import { storageUploadHint, uploadUserProfilePhoto } from "@/lib/media-upload";
import { completePlayerOnboarding } from "@/repositories";
import type { UserProfile } from "@/types/models";

/** Same 6 steps as Flutter `PlayerOnboardingScreen`. */
const STEP_COUNT = 6;

const selectClass =
  "h-11 w-full rounded-xl border border-border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring";

function splitPhone(e164?: string): { dial: string; national: string } {
  if (!e164) return { dial: "+94", national: "" };
  const match = PHONE_DIAL_CODES.slice()
    .sort((a, b) => b.length - a.length)
    .find((d) => e164.startsWith(d));
  if (match) return { dial: match, national: e164.slice(match.length) };
  return { dial: "+94", national: e164.replace(/^\+\d+\s*/, "") };
}

export function PlayerOnboardingForm({
  user,
  profile,
}: {
  user: User;
  profile: UserProfile | null;
}) {
  const { refreshProfile, logout } = useAuth();
  const router = useRouter();
  const [step, setStep] = useState(0);
  const [busy, setBusy] = useState(false);

  const [photos, setPhotos] = useState<File[]>([]);
  const [name, setName] = useState(profile?.name || user.displayName || "");
  const [displayName, setDisplayName] = useState(profile?.displayName || user.displayName || "");
  const initialPhone = splitPhone(profile?.phoneNumber || user.phoneNumber || undefined);
  const [dialCode, setDialCode] = useState(initialPhone.dial);
  const [mobileNational, setMobileNational] = useState(initialPhone.national);
  const [country, setCountry] = useState(profile?.location?.country || "Sri Lanka");
  const [stateProvince, setStateProvince] = useState(profile?.location?.stateProvince || "");
  const [city, setCity] = useState(profile?.location?.city || "");
  const [dob, setDob] = useState(
    profile?.dateOfBirth ? profile.dateOfBirth.slice(0, 10) : "",
  );
  const [gender, setGender] = useState<PlayerGender | "">(
    (profile?.gender as PlayerGender | undefined) ?? "",
  );
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
  const [jersey, setJersey] = useState(
    profile?.jerseyNumber != null ? String(profile.jerseyNumber) : "",
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
        const mobile = mobileNational.trim();
        if (mobile && !/^[0-9]{6,14}$/.test(mobile)) {
          return "Enter a valid mobile number (digits only)";
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
      case 5: {
        const j = jersey.trim();
        if (!j) return null;
        const n = Number(j);
        if (!Number.isInteger(n) || n < 0 || n > 999) return "Jersey number must be 0–999";
        return null;
      }
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

      const mobile = mobileNational.trim();
      const phoneNumber = mobile ? `${dialCode}${mobile}` : profile?.phoneNumber || user.phoneNumber || undefined;
      const jerseyNumber = jersey.trim() ? Number(jersey.trim()) : undefined;

      await completePlayerOnboarding({
        id: user.uid,
        email: profile?.email ?? user.email ?? "",
        phoneNumber,
        name: name.trim(),
        displayName: displayName.trim() || name.trim(),
        photoUrl,
        role: profile?.role ?? "organizer",
        location: {
          country: country.trim(),
          stateProvince: stateProvince.trim(),
          district: profile?.location?.district ?? "",
          city: city.trim(),
          placeName: profile?.location?.placeName ?? "",
        },
        bio: profile?.bio ?? "",
        playingRole,
        battingStyle,
        bowlingStyle: resolvedBowling,
        jerseyNumber,
        dateOfBirth: dob || undefined,
        gender: gender || undefined,
        playerId: profile?.playerId,
      });
      await refreshProfile();
      router.replace(takePendingNext("/"));
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
      <div className="flex items-start justify-between gap-3">
        <div className="flex-1">
          <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
            Step {step + 1} of {STEP_COUNT}
          </p>
          <div className="mt-2 h-2 overflow-hidden rounded-full bg-muted">
            <div className="h-full rounded-full bg-primary transition-all" style={{ width: `${progress}%` }} />
          </div>
        </div>
        <Button
          type="button"
          variant="ghost"
          size="sm"
          className="shrink-0 text-muted-foreground"
          disabled={busy}
          onClick={async () => {
            await logout();
            router.replace("/login/");
          }}
        >
          Sign out
        </Button>
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
          <p className="text-sm text-muted-foreground">Tell us about yourself. Fields marked * are required.</p>
          <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="Full name *" required />
          <Input
            value={displayName}
            onChange={(e) => setDisplayName(e.target.value)}
            placeholder="Display name (optional)"
          />
          <select
            className={selectClass}
            value={country}
            onChange={(e) => {
              const c = e.target.value;
              setCountry(c);
              setDialCode(dialCodeForCountry(c));
            }}
          >
            {COMMON_COUNTRIES.map((c) => (
              <option key={c} value={c}>
                {c}
              </option>
            ))}
          </select>
          <div className="grid gap-2 sm:grid-cols-2">
            <Input
              value={stateProvince}
              onChange={(e) => setStateProvince(e.target.value)}
              placeholder="State / Province"
            />
            <Input value={city} onChange={(e) => setCity(e.target.value)} placeholder="City" />
          </div>
          <div className="flex gap-2">
            <select className={`${selectClass} w-28 shrink-0`} value={dialCode} onChange={(e) => setDialCode(e.target.value)}>
              {PHONE_DIAL_CODES.map((d) => (
                <option key={d} value={d}>
                  {d}
                </option>
              ))}
            </select>
            <Input
              value={mobileNational}
              onChange={(e) => setMobileNational(e.target.value.replace(/\D/g, ""))}
              placeholder={phoneNumberHint(dialCode)}
              inputMode="numeric"
              className="flex-1"
            />
          </div>
          <Input type="date" value={dob} onChange={(e) => setDob(e.target.value)} max={new Date().toISOString().slice(0, 10)} />
          <select className={selectClass} value={gender} onChange={(e) => setGender(e.target.value as PlayerGender | "")}>
            <option value="">Gender (optional)</option>
            {PLAYER_GENDERS.map((g) => (
              <option key={g} value={g}>
                {PLAYER_GENDER_LABELS[g]}
              </option>
            ))}
          </select>
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

      {step === 5 ? (
        <section className="space-y-4">
          <h1 className="text-2xl font-bold">Jersey number</h1>
          <p className="text-sm text-muted-foreground">Optional — 0–999.</p>
          <Input
            value={jersey}
            onChange={(e) => setJersey(e.target.value.replace(/\D/g, "").slice(0, 3))}
            placeholder="e.g. 7"
            inputMode="numeric"
          />
        </section>
      ) : null}

      <div className="flex gap-2">
        {step > 0 ? (
          <Button type="button" variant="outline" onClick={back} disabled={busy}>
            Back
          </Button>
        ) : null}
        <Button type="button" className="flex-1" onClick={next} disabled={busy}>
          {busy ? "Saving…" : step === STEP_COUNT - 1 ? "Finish" : step === 0 ? "Skip photo" : "Save & Continue"}
        </Button>
      </div>
    </Card>
  );
}
