"use client";

import { Suspense, useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { AuthShell } from "@/components/layout/auth-shell";
import { LoadingPage } from "@/components/shared/page-shell";
import { useAuth } from "@/features/auth/auth-provider";
import { PhoneRecaptchaHost } from "@/components/auth/phone-recaptcha-host";
import { authErrorMessage } from "@/lib/auth-errors";

function readInvitePhone() {
  if (typeof window === "undefined") return "";
  try {
    return sessionStorage.getItem("cf_invite_phone") ?? "";
  } catch {
    return "";
  }
}

function LoginForm() {
  const { user, profile, loading, signInGoogle, signInEmail, registerEmail, sendPhoneCode, confirmPhoneCode } = useAuth();
  const router = useRouter();
  const searchParams = useSearchParams();
  const [phone, setPhone] = useState(readInvitePhone);
  const [code, setCode] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [verificationId, setVerificationId] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  const next = searchParams.get("next");
  const nextPath = next?.startsWith("/") ? next : "/";
  const inviteLogin = nextPath.startsWith("/invite/");

  useEffect(() => {
    if (loading || !user || !profile) return;
    if (nextPath.startsWith("/invite/")) {
      router.replace(nextPath);
      return;
    }
    router.replace(profile.onboardingCompleted ? nextPath : "/register");
  }, [loading, user, profile, router, nextPath]);

  if (loading) return <LoadingPage title="Loading sign in" />;

  return (
    <AuthShell
      title="Sign in to CrickFlow"
      subtitle={
        inviteLogin
          ? "Accept with Google or the invited mobile number — both work."
          : "Same Firebase account as the mobile app — Google, phone, or email."
      }
    >
      <Button
        className="w-full"
        size="lg"
        disabled={busy}
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

      <div className="relative my-6 text-center text-xs uppercase tracking-wider text-muted-foreground">
        <span className="bg-card px-2">or email</span>
        <div className="absolute inset-x-0 top-1/2 -z-10 border-t border-border" aria-hidden />
      </div>

      <div className="space-y-3">
        <Input
          type="email"
          placeholder="Email address"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          autoComplete="email"
        />
        <Input
          type="password"
          placeholder="Password (min 6 characters)"
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
            Sign in
          </Button>
          <Button
            variant="secondary"
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

      <div className="relative my-6 text-center text-xs uppercase tracking-wider text-muted-foreground">
        <span className="bg-card px-2">or phone</span>
        <div className="absolute inset-x-0 top-1/2 -z-10 border-t border-border" aria-hidden />
      </div>

      <div className="space-y-3">
        <Input
          placeholder="+94 mobile number"
          value={phone}
          onChange={(e) => setPhone(e.target.value)}
          autoComplete="tel"
        />
        <PhoneRecaptchaHost id="recaptcha-container" />
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
              Verify & sign in
            </Button>
          </>
        ) : null}
      </div>

      {error ? <p className="mt-4 rounded-xl bg-live/10 px-3 py-2 text-sm text-live">{error}</p> : null}
    </AuthShell>
  );
}

export default function LoginPage() {
  return (
    <Suspense fallback={<LoadingPage title="Loading sign in" />}>
      <LoginForm />
    </Suspense>
  );
}
