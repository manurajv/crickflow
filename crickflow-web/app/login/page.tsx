"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { useAuth } from "@/features/auth/auth-provider";
import { authErrorMessage } from "@/lib/auth-errors";

function nextPath() {
  const next = new URLSearchParams(window.location.search).get("next");
  return next?.startsWith("/") ? next : "/";
}

export default function LoginPage() {
  const { user, profile, loading, signInGoogle, signInEmail, registerEmail, sendPhoneCode, confirmPhoneCode } = useAuth();
  const router = useRouter();
  const [phone, setPhone] = useState("");
  const [code, setCode] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [verificationId, setVerificationId] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (loading || !user || !profile) return;
    router.replace(profile.onboardingCompleted ? nextPath() : "/register");
  }, [loading, user, profile, router]);

  return (
    <Card className="mx-auto max-w-md p-8">
      <h1 className="text-2xl font-bold">Sign in to CrickFlow</h1>
      <p className="mt-1 text-sm text-muted-foreground">
        Same Firebase Authentication as the mobile app — Google, phone, or email.
      </p>
      <div id="recaptcha-container" />
      <Button
        className="mt-6 w-full"
        disabled={busy || loading}
        onClick={async () => {
          setBusy(true);
          setError("");
          try {
            await signInGoogle();
          } catch (err) {
            setError(authErrorMessage(err));
          } finally {
            setBusy(false);
          }
        }}
      >
        Continue with Google
      </Button>
      <div className="mt-6 space-y-3">
        <Input
          type="email"
          placeholder="Email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          autoComplete="email"
        />
        <Input
          type="password"
          placeholder="Password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          autoComplete="current-password"
        />
        <div className="grid grid-cols-2 gap-2">
          <Button
            variant="outline"
            disabled={busy || !email.trim() || password.length < 6}
            onClick={async () => {
              setBusy(true);
              setError("");
              try {
                await signInEmail(email, password);
              } catch (err) {
                setError(authErrorMessage(err));
              } finally {
                setBusy(false);
              }
            }}
          >
            Email sign in
          </Button>
          <Button
            variant="outline"
            disabled={busy || !email.trim() || password.length < 6}
            onClick={async () => {
              setBusy(true);
              setError("");
              try {
                await registerEmail(email, password);
              } catch (err) {
                setError(authErrorMessage(err));
              } finally {
                setBusy(false);
              }
            }}
          >
            Create account
          </Button>
        </div>
      </div>
      <div className="mt-6 space-y-3">
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
          onClick={async () => {
            setBusy(true);
            setError("");
            try {
              const id = await sendPhoneCode(phone, "recaptcha-container");
              setVerificationId(id);
            } catch (err) {
              setError(authErrorMessage(err));
            } finally {
              setBusy(false);
            }
          }}
        >
          Send OTP
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
              onClick={async () => {
                setBusy(true);
                setError("");
                try {
                  await confirmPhoneCode(verificationId, code);
                } catch (err) {
                  setError(authErrorMessage(err));
                } finally {
                  setBusy(false);
                }
              }}
            >
              Verify
            </Button>
          </>
        ) : null}
      </div>
      {error ? <p className="mt-4 text-sm text-live">{error}</p> : null}
    </Card>
  );
}
