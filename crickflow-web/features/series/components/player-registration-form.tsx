"use client";

import { FormEvent, useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { useAuth } from "@/features/auth/auth-provider";
import type { SeriesSettings } from "@/features/series/types";
import {
  deleteStorageUrl,
  uploadSeriesRegistrationImage,
} from "@/lib/media-upload";

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
};

export function PlayerRegistrationForm({
  seriesId,
  settings,
  clubs,
  onSubmit,
  pending,
}: Props) {
  const { user } = useAuth();
  const approved = useMemo(
    () => clubs.filter((c) => c.status === "approved"),
    [clubs],
  );
  const [clubId, setClubId] = useState("");
  const [fullName, setFullName] = useState(user?.displayName || "");
  const [playerId, setPlayerId] = useState(user?.uid || "");
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

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError("");
    if (!clubId || !user) return;
    if (settings.requireFullName && !fullName.trim()) {
      setError("Full name is required");
      return;
    }
    if (settings.requireCrickFlowPlayerId && !playerId.trim()) {
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
    if (settings.requireProfilePhoto && !profileFile) {
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
    try {
      let profilePhotoUrl: string | undefined;
      let nationalIdDocUrl: string | undefined;
      let passportDocUrl: string | undefined;
      const opts = { clubId, subjectUserId: user.uid };
      if (profileFile) {
        profilePhotoUrl = await uploadSeriesRegistrationImage(
          seriesId, user.uid, profileFile, "photo", opts,
        );
        uploaded.push(profilePhotoUrl);
      }
      if (nationalDoc) {
        nationalIdDocUrl = await uploadSeriesRegistrationImage(
          seriesId, user.uid, nationalDoc, "doc", opts,
        );
        uploaded.push(nationalIdDocUrl);
      }
      if (passportDoc) {
        passportDocUrl = await uploadSeriesRegistrationImage(
          seriesId, user.uid, passportDoc, "doc", opts,
        );
        uploaded.push(passportDocUrl);
      }
      await onSubmit({
        clubId,
        fullName: fullName.trim(),
        crickFlowPlayerId: playerId.trim() || undefined,
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
      setError(err instanceof Error ? err.message : "Could not submit registration");
    }
  }

  function fileInput(
    label: string,
    required: boolean,
    onChange: (f: File | null) => void,
    current: File | null,
  ) {
    return (
      <label className="block text-sm">
        {label}{required ? " *" : ""}
        <input
          type="file"
          accept="image/*"
          className="mt-1 block w-full text-sm"
          onChange={(e) => onChange(e.target.files?.[0] || null)}
        />
        {current ? <span className="text-xs text-muted-foreground">{current.name}</span> : null}
      </label>
    );
  }

  return (
    <form className="space-y-3" onSubmit={handleSubmit}>
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
      {(settings.requireFullName || true) && (
        <input
          className="w-full rounded-md border border-border bg-background px-3 py-2"
          placeholder={settings.requireFullName ? "Your name *" : "Your name"}
          value={fullName}
          onChange={(e) => setFullName(e.target.value)}
          required={settings.requireFullName}
        />
      )}
      {settings.requireCrickFlowPlayerId && (
        <input
          className="w-full rounded-md border border-border bg-background px-3 py-2"
          placeholder="CrickFlow Player ID *"
          value={playerId}
          onChange={(e) => setPlayerId(e.target.value)}
          required
        />
      )}
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
      {settings.requireProfilePhoto &&
        fileInput("Profile photo", true, setProfileFile, profileFile)}
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
        {pending ? "…" : "Request to join"}
      </Button>
      <p className="text-xs text-muted-foreground">
        The team admin reviews your documents first, then organization admins make the final decision.
        ID documents stay private to you, team admins, and organization admins.
      </p>
    </form>
  );
}
