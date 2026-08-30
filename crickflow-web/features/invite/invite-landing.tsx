"use client";

import { httpsCallable } from "firebase/functions";
import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { GetTheApp } from "@/components/shared/get-the-app";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { useAuth } from "@/features/auth/auth-provider";
import { PhoneRecaptchaHost } from "@/components/auth/phone-recaptcha-host";
import { getFirebaseFunctions } from "@/lib/firebase/client";
import { authErrorMessage } from "@/lib/auth-errors";
import { usePathParam } from "@/lib/use-path-param";
import { getPlayerInvite, type PlayerInvite } from "@/repositories";

function maskPhone(phone: string) {
  const digits = phone.replace(/\D/g, "");
  if (digits.length < 6) return phone;
  return `+••••${digits.slice(-4)}`;
}

export function InviteLanding() {
  const token = usePathParam("token", 1);
  const router = useRouter();
  const {
    user,
    loading,
    signInGoogle,
    sendPhoneCode,
    confirmPhoneCode,
    refreshProfile,
  } = useAuth();
  const invalidToken = !token || token === "_";
  const [invite, setInvite] = useState<PlayerInvite | null>(null);
  const [error, setError] = useState(invalidToken ? "This invite link is not valid" : "");
  const [busy, setBusy] = useState(false);
  const [ready, setReady] = useState(invalidToken);
  const [showPhone, setShowPhone] = useState(false);
  const [phone, setPhone] = useState("");
  const [code, setCode] = useState("");
  const [verificationId, setVerificationId] = useState("");
  const [nowMs] = useState(() => Date.now());

  useEffect(() => {
    if (invalidToken) return;
    let cancelled = false;
    void getPlayerInvite(token)
      .then((next) => {
        if (cancelled) return;
        setInvite(next);
        if (!next) {
          setError("This invite link is not valid");
          return;
        }
        if (next.phoneNumber) setPhone(next.phoneNumber);
      })
      .catch(() => {
        if (!cancelled) setError("Could not load this invite");
      })
      .finally(() => {
        if (!cancelled) setReady(true);
      });
    return () => {
      cancelled = true;
    };
  }, [token, invalidToken]);

  async function acceptInvite() {
    if (!token) return;
    const fn = httpsCallable(getFirebaseFunctions(), "acceptPlayerInvite");
    await fn({ inviteId: token });
    await refreshProfile();
    const { getFirebaseAuth } = await import("@/lib/firebase/client");
    const { getUserProfile } = await import("@/repositories");
    const uid = getFirebaseAuth().currentUser?.uid;
    const next = uid ? await getUserProfile(uid) : null;
    router.replace(next?.onboardingCompleted ? "/" : "/register");
  }

  async function afterAuthAccept() {
    setBusy(true);
    setError("");
    try {
      await acceptInvite();
    } catch (err) {
      setError(authErrorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  async function onGoogle() {
    setBusy(true);
    setError("");
    try {
      await signInGoogle();
      await acceptInvite();
    } catch (err) {
      setError(authErrorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  async function onSendOtp() {
    setBusy(true);
    setError("");
    try {
      const id = await sendPhoneCode(phone, "invite-recaptcha");
      setVerificationId(id);
    } catch (err) {
      setError(authErrorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  async function onVerifyOtp() {
    setBusy(true);
    setError("");
    try {
      await confirmPhoneCode(verificationId, code);
      await acceptInvite();
    } catch (err) {
      setError(authErrorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  const expired =
    invite?.status === "expired" ||
    (invite?.expiresAt ? Date.parse(invite.expiresAt) < nowMs : false);
  const pending = invite?.status === "pending" && !expired;
  const hasPhoneTarget = Boolean(invite?.phoneNumber);

  return (
    <Card className="mx-auto max-w-lg p-8">
      <h1 className="text-2xl font-bold">You’re invited to CrickFlow</h1>
      {!ready ? (
        <p className="mt-3 text-sm text-muted-foreground">Loading invite…</p>
      ) : invite ? (
        <>
          <p className="mt-2 text-muted-foreground">
            {invite.invitedByName} invited you to join
            {invite.displayName ? ` as ${invite.displayName}` : ""}. Sign in with{" "}
            <strong>Google</strong> or your <strong>mobile number</strong>
            {hasPhoneTarget ? ` (${maskPhone(invite.phoneNumber)})` : ""} — whichever
            you prefer.
          </p>

          {pending && !loading && !user ? (
            <div className="mt-6 space-y-3">
              <Button className="w-full" disabled={busy} onClick={() => void onGoogle()}>
                Continue with Google
              </Button>
              <Button
                variant="outline"
                className="w-full"
                disabled={busy}
                onClick={() => setShowPhone((v) => !v)}
              >
                Sign in with phone
              </Button>
              {showPhone ? (
                <div className="space-y-3 rounded-xl border border-border p-4">
                  <PhoneRecaptchaHost id="invite-recaptcha" />
                  <Input
                    placeholder="+94…"
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    autoComplete="tel"
                  />
                  <Button
                    variant="outline"
                    className="w-full"
                    disabled={busy || !phone.trim()}
                    onClick={() => void onSendOtp()}
                  >
                    {busy && !verificationId ? "Sending…" : "Send OTP"}
                  </Button>
                  {verificationId ? (
                    <>
                      <Input
                        placeholder="6-digit code"
                        value={code}
                        onChange={(e) => setCode(e.target.value)}
                        inputMode="numeric"
                        autoComplete="one-time-code"
                      />
                      <Button
                        className="w-full"
                        disabled={busy || code.trim().length < 6}
                        onClick={() => void onVerifyOtp()}
                      >
                        Verify & accept
                      </Button>
                    </>
                  ) : null}
                </div>
              ) : null}
            </div>
          ) : null}

          {pending && user ? (
            <Button
              className="mt-6 w-full"
              disabled={busy}
              onClick={() => void afterAuthAccept()}
            >
              {busy ? "Accepting…" : "Accept invite"}
            </Button>
          ) : null}

          {invite.status === "accepted" ? (
            <p className="mt-4 text-sm">This invite has already been accepted.</p>
          ) : null}
          {expired ? <p className="mt-4 text-sm">This invite has expired.</p> : null}
        </>
      ) : null}
      {error ? <p className="mt-4 text-sm text-live">{error}</p> : null}
      <div className="mt-8">
        <GetTheApp
          title="Prefer the CrickFlow app?"
          description="If the app is installed, this same link can open it. Otherwise stay here and join with Google or phone."
        />
      </div>
      <p className="mt-4 text-center text-sm text-muted-foreground">
        <Link href="/login" className="underline">
          Already have an account? Sign in
        </Link>
      </p>
    </Card>
  );
}
