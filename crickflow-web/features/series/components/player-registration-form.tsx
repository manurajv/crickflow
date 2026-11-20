"use client";

import { FormEvent, useEffect, useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { useAuth } from "@/features/auth/auth-provider";
import type { SeriesSettings } from "@/features/series/types";
import { officialIdentityFromProfile } from "@/lib/cricket/official-identity";
import {
  deleteStorageUrl,
  uploadSeriesRegistrationImage,
} from "@/lib/media-upload";
import { friendlyError, friendlyUploadError } from "@/lib/friendly-error";
import { ImageCropDialog, type ImageCropMode } from "@/components/shared/image-crop-dialog";

export type PlayerRegistrationValues = {
  clubId: string;
  fullName: string;
  crickFlowPlayerId?: string;
  phoneNumber?: string;
  address?: string;
  dateOfBirth?: string;
  nationalId?: string;
  passportNumber?: string;
  profilePhotoUrl?: string;
  nationalIdDocUrl?: string;
  passportDocUrl?: string;
  customFields?: Record<string, string>;
};

type Props = {
  seriesId: string;
  settings: SeriesSettings;
  clubs: Array<{ id: string; name: string; status: string }>;
  onSubmit: (values: PlayerRegistrationValues) => Promise<void>;
  pending?: boolean;
  lockIdentity?: boolean;
  fixedClubId?: string;
  identity?: { fullName: string; crickFlowPlayerId: string };
  subjectUserId?: string;
  submitLabel?: string;
  pendingLabel?: string;
  /** Official profile photo already on the player; reused when no new file is chosen. */
  existingProfilePhotoUrl?: string;
};

function LockedField({
  label,
  value,
  testId,
}: {
  label: string;
  value: string;
  testId: string;
}) {
  return (
    <label className="block text-sm">
      {label}
      <span className="relative mt-1 block">
        <input
          data-testid={testId}
          className="w-full rounded-md border border-border bg-muted/40 px-3 py-2 pr-9"
          value={value}
          readOnly
          aria-readonly="true"
        />
        <span
          className="pointer-events-none absolute inset-y-0 right-2 flex items-center text-muted-foreground"
          aria-hidden
        >
          🔒
        </span>
      </span>
    </label>
  );
}

export function PlayerRegistrationForm({
  seriesId,
  settings,
  clubs,
  onSubmit,
  pending,
  lockIdentity = true,
  fixedClubId,
  identity,
  subjectUserId,
  submitLabel = "Request to join",
  pendingLabel,
  existingProfilePhotoUrl,
}: Props) {
  const { user, profile } = useAuth();
  const official = identity ?? officialIdentityFromProfile(profile);
  const approved = useMemo(
    () => clubs.filter((c) => c.status === "approved"),
    [clubs],
  );
  const [clubId, setClubId] = useState(fixedClubId || "");
  const [fullName, setFullName] = useState(official.fullName);
  const [playerId, setPlayerId] = useState(official.crickFlowPlayerId);
  const [phone, setPhone] = useState("");
  const [address, setAddress] = useState("");
  const [dob, setDob] = useState("");
  const [nationalId, setNationalId] = useState("");
  const [passport, setPassport] = useState("");
  const [custom, setCustom] = useState<Record<string, string>>({});
  const [profileFile, setProfileFile] = useState<File | null>(null);
  const [nationalDoc, setNationalDoc] = useState<File | null>(null);
  const [passportDoc, setPassportDoc] = useState<File | null>(null);
  const [error, setError] = useState("");
  const [crop, setCrop] = useState<{
    file: File;
    mode: ImageCropMode;
    title: string;
    apply: (file: File) => void;
  } | null>(null);
  const existingPhoto = (existingProfilePhotoUrl || "").trim();

  useEffect(() => {
    if (fixedClubId) setClubId(fixedClubId);
  }, [fixedClubId]);

  useEffect(() => {
    if (!lockIdentity) return;
    setFullName(official.fullName);
    setPlayerId(official.crickFlowPlayerId);
  }, [lockIdentity, official.fullName, official.crickFlowPlayerId]);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError("");
    if (!clubId || !user) return;
    const submittedName = lockIdentity ? official.fullName : fullName.trim();
    const submittedId = lockIdentity ? official.crickFlowPlayerId : playerId.trim();
    if (settings.requireFullName && !submittedName) {
      setError("Full name is required");
      return;
    }
    if (settings.requireCrickFlowPlayerId && !submittedId) {
      setError("CrickFlow Player ID is required");
      return;
    }
    if (settings.requireDateOfBirth && !dob) {
      setError("Date of birth is required");
      return;
    }
    if (settings.requirePhoneNumber && !phone.trim()) {
      setError("Phone number is required");
      return;
    }
    if (settings.requireAddress && !address.trim()) {
      setError("Address is required");
      return;
    }
    if (settings.requireNationalId && !nationalId.trim()) {
      setError("National ID is required");
      return;
    }
    if (settings.requirePassport && !passport.trim()) {
      setError("Passport number is required");
      return;
    }
    if (settings.requireProfilePhoto && !profileFile && !existingPhoto) {
      setError("Profile photo is required");
      return;
    }
    if (settings.requireNationalIdDocument && !nationalDoc) {
      setError("National ID document photo is required");
      return;
    }
    if (settings.requirePassportDocument && !passportDoc) {
      setError("Passport document photo is required");
      return;
    }
    for (const key of settings.customRequiredFields || []) {
      if (!String(custom[key] || "").trim()) {
        setError(`${key} is required`);
        return;
      }
    }

    const uploaded: string[] = [];
    const ownerId = subjectUserId || user.uid;
    try {
      let profilePhotoUrl: string | undefined = existingPhoto || undefined;
      let nationalIdDocUrl: string | undefined;
      let passportDocUrl: string | undefined;
      const opts = { clubId, subjectUserId: ownerId };
      if (profileFile) {
        profilePhotoUrl = await uploadSeriesRegistrationImage(
          seriesId, ownerId, profileFile, "photo", opts,
        );
        uploaded.push(profilePhotoUrl);
      }
      if (nationalDoc) {
        nationalIdDocUrl = await uploadSeriesRegistrationImage(
          seriesId, ownerId, nationalDoc, "doc", opts,
        );
        uploaded.push(nationalIdDocUrl);
      }
      if (passportDoc) {
        passportDocUrl = await uploadSeriesRegistrationImage(
          seriesId, ownerId, passportDoc, "doc", opts,
        );
        uploaded.push(passportDocUrl);
      }
      await onSubmit({
        clubId,
        fullName: submittedName,
        crickFlowPlayerId: submittedId || undefined,
        phoneNumber: phone.trim() || undefined,
        address: address.trim() || undefined,
        dateOfBirth: dob || undefined,
        nationalId: nationalId.trim() || undefined,
        passportNumber: passport.trim() || undefined,
        profilePhotoUrl,
        nationalIdDocUrl,
        passportDocUrl,
        customFields: custom,
      });
    } catch (err) {
      await Promise.all(uploaded.map((url) => deleteStorageUrl(url).catch(() => undefined)));
      setError(friendlyUploadError(err));
    }
  }

  function pickCropped(
    title: string,
    apply: (file: File) => void,
  ) {
    return (file: File | null) => {
      if (!file) {
        apply(file as unknown as File);
        return;
      }
      setCrop({ file, mode: "document", title, apply });
    };
  }

  function fileInput(
    label: string,
    required: boolean,
    onChange: (f: File | null) => void,
    current: File | null,
    extra?: string,
  ) {
    return (
      <label className="block text-sm">
        {label}{required ? " *" : ""}
        <input
          type="file"
          accept="image/*"
          className="mt-1 block w-full text-sm"
          onChange={(e) => {
            const next = e.target.files?.[0] || null;
            e.target.value = "";
            if (!next) {
              onChange(null);
              return;
            }
            pickCropped(`Crop ${label.replace(/ \*$/, "")}`, onChange)(next);
          }}
        />
        {current ? <span className="text-xs text-muted-foreground">{current.name}</span> : null}
        {!current && extra ? <span className="block text-xs text-muted-foreground">{extra}</span> : null}
      </label>
    );
  }

  const showName = settings.requireFullName || lockIdentity;
  const showPlayerId = settings.requireCrickFlowPlayerId || lockIdentity;

  return (
    <>
    <form className="space-y-3" onSubmit={handleSubmit}>
      {fixedClubId ? null : (
        <select
          className="w-full rounded-md border border-border bg-background px-3 py-2"
          value={clubId}
          onChange={(e) => setClubId(e.target.value)}
          required
        >
          <option value="">Join a team</option>
          {approved.map((c) => (
            <option key={c.id} value={c.id}>{c.name}</option>
          ))}
        </select>
      )}
      {showName && (lockIdentity ? (
        <LockedField
          label={settings.requireFullName ? "Full name *" : "Full name"}
          value={fullName}
          testId="org-registration-full-name"
        />
      ) : (
        <input
          className="w-full rounded-md border border-border bg-background px-3 py-2"
          placeholder={settings.requireFullName ? "Your name *" : "Your name"}
          value={fullName}
          onChange={(e) => setFullName(e.target.value)}
          required={settings.requireFullName}
        />
      ))}
      {showPlayerId && (lockIdentity ? (
        <LockedField
          label={settings.requireCrickFlowPlayerId ? "CrickFlow Player ID *" : "CrickFlow Player ID"}
          value={playerId}
          testId="org-registration-player-id"
        />
      ) : (
        <input
          className="w-full rounded-md border border-border bg-background px-3 py-2"
          placeholder="CrickFlow Player ID *"
          value={playerId}
          onChange={(e) => setPlayerId(e.target.value)}
          required={settings.requireCrickFlowPlayerId}
        />
      ))}
      {settings.requirePhoneNumber && (
        <input
          className="w-full rounded-md border border-border bg-background px-3 py-2"
          placeholder="Phone number *"
          value={phone}
          onChange={(e) => setPhone(e.target.value)}
          required
        />
      )}
      {settings.requireDateOfBirth && (
        <label className="block text-sm">
          Date of birth *
          <input
            type="date"
            className="mt-1 w-full rounded-md border border-border bg-background px-3 py-2"
            value={dob}
            onChange={(e) => setDob(e.target.value)}
            required
          />
        </label>
      )}
      {settings.requireAddress && (
        <input
          className="w-full rounded-md border border-border bg-background px-3 py-2"
          placeholder="Address *"
          value={address}
          onChange={(e) => setAddress(e.target.value)}
          required
        />
      )}
      {(settings.requireProfilePhoto || existingPhoto) &&
        fileInput(
          "Profile photo",
          Boolean(settings.requireProfilePhoto),
          setProfileFile,
          profileFile,
          existingPhoto && !profileFile ? "Using this player's existing profile photo" : undefined,
        )}
      {(settings.requireNationalId || settings.requireNationalIdDocument) && (
        <>
          {settings.requireNationalId && (
            <input
              className="w-full rounded-md border border-border bg-background px-3 py-2"
              placeholder="National ID / ID number *"
              value={nationalId}
              onChange={(e) => setNationalId(e.target.value)}
              required
            />
          )}
          {fileInput(
            "National ID document photo",
            settings.requireNationalIdDocument,
            setNationalDoc,
            nationalDoc,
          )}
        </>
      )}
      {(settings.requirePassport || settings.requirePassportDocument) && (
        <>
          {settings.requirePassport && (
            <input
              className="w-full rounded-md border border-border bg-background px-3 py-2"
              placeholder="Passport number *"
              value={passport}
              onChange={(e) => setPassport(e.target.value)}
              required
            />
          )}
          {fileInput(
            "Passport document photo",
            settings.requirePassportDocument,
            setPassportDoc,
            passportDoc,
          )}
        </>
      )}
      {(settings.customRequiredFields || []).map((key) => (
        <input
          key={key}
          className="w-full rounded-md border border-border bg-background px-3 py-2"
          placeholder={`${key} *`}
          value={custom[key] || ""}
          onChange={(e) => setCustom((c) => ({ ...c, [key]: e.target.value }))}
          required
        />
      ))}
      {error ? <p className="text-sm text-destructive">{error}</p> : null}
      <Button type="submit" variant="outline" disabled={pending || !clubId}>
        {pending ? (pendingLabel ?? "Sending request…") : submitLabel}
      </Button>
      <p className="text-xs text-muted-foreground">
        The team admin reviews your documents first, then organization admins make the final decision.
        ID documents stay private to you, team admins, and organization admins.
      </p>
    </form>
      {crop ? (
        <ImageCropDialog
          file={crop.file}
          mode={crop.mode}
          title={crop.title}
          onCancel={() => setCrop(null)}
          onConfirm={(file) => {
            crop.apply(file);
            setCrop(null);
          }}
        />
      ) : null}
    </>
  );
}
