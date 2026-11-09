"use client";

import {
  GoogleAuthProvider,
  createUserWithEmailAndPassword,
  getRedirectResult,
  initializeRecaptchaConfig,
  onAuthStateChanged,
  sendPasswordResetEmail,
  signInWithEmailAndPassword,
  signInWithPopup,
  signInWithRedirect,
  signOut,
  type User,
} from "firebase/auth";
import { createContext, useContext, useEffect, useMemo, useState } from "react";
import { getFirebaseAuth, isFirebaseConfigured } from "@/lib/firebase/client";
import {
  confirmPhoneVerificationCode,
  sendPhoneVerificationCode,
} from "@/lib/firebase/phone-auth";
import { getUserProfile, upsertUserProfile } from "@/repositories";
import type { UserProfile } from "@/types/models";
import { getPlatformAdminInfo } from "@/lib/auth/platform-admin";

export { normalizePhoneE164 } from "@/lib/firebase/phone-auth";

interface AuthContextValue {
  user: User | null;
  profile: UserProfile | null;
  isPlatformAdmin: boolean;
  loading: boolean;
  signInGoogle: () => Promise<void>;
  signInEmail: (email: string, password: string) => Promise<void>;
  registerEmail: (email: string, password: string) => Promise<void>;
  resetPassword: (email: string) => Promise<void>;
  sendPhoneCode: (phone: string, recaptchaId: string) => Promise<string>;
  confirmPhoneCode: (verificationId: string, code: string) => Promise<void>;
  logout: () => Promise<void>;
  refreshProfile: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [isPlatformAdmin, setIsPlatformAdmin] = useState(false);
  const [loading, setLoading] = useState(() => isFirebaseConfigured());

  useEffect(() => {
    if (!isFirebaseConfigured()) return;
    const auth = getFirebaseAuth();
    void initializeRecaptchaConfig(auth).catch(() => undefined);
    void getRedirectResult(auth).catch(() => undefined);
    const unsub = onAuthStateChanged(auth, async (next) => {
      setUser(next);
      if (!next) {
        setProfile(null);
        setIsPlatformAdmin(false);
        setLoading(false);
        return;
      }
      try {
        const adminInfo = await getPlatformAdminInfo(next.uid);
        setIsPlatformAdmin(adminInfo.isPlatformAdmin);
        let existing = await getUserProfile(next.uid);
        if (!existing) {
          const stub = {
            id: next.uid,
            email: next.email ?? "",
            name: next.displayName ?? "",
            displayName: next.displayName ?? "CrickFlow User",
            photoUrl: next.photoURL ?? undefined,
            phoneNumber: next.phoneNumber ?? undefined,
            role: "organizer",
            bio: "",
            location: {
              country: "",
              stateProvince: "",
              district: "",
              city: "",
              placeName: "",
            },
            // Platform staff use the admin panels; skip forcing player onboarding.
            onboardingCompleted: adminInfo.isPlatformAdmin,
          };
          try {
            await upsertUserProfile(stub);
            existing = (await getUserProfile(next.uid)) ?? stub;
          } catch {
            existing = stub;
          }
        } else if (
          adminInfo.isPlatformAdmin &&
          !existing.onboardingCompleted
        ) {
          // Staff account with incomplete player profile — do not block the website.
          existing = { ...existing, onboardingCompleted: true };
        }
        setProfile(existing);
      } finally {
        setLoading(false);
      }
    });
    return () => unsub();
  }, []);

  const value = useMemo<AuthContextValue>(
    () => ({
      user,
      profile,
      isPlatformAdmin,
      loading,
      signInGoogle: async () => {
        const auth = getFirebaseAuth();
        const provider = new GoogleAuthProvider();
        try {
          await signInWithPopup(auth, provider);
        } catch (error) {
          const code = typeof error === "object" && error && "code" in error ? String(error.code) : "";
          if (code === "auth/popup-blocked" || code === "auth/popup-closed-by-user") {
            await signInWithRedirect(auth, provider);
            return;
          }
          throw error;
        }
      },
      signInEmail: async (email, password) => {
        await signInWithEmailAndPassword(getFirebaseAuth(), email.trim(), password);
      },
      registerEmail: async (email, password) => {
        await createUserWithEmailAndPassword(getFirebaseAuth(), email.trim(), password);
      },
      resetPassword: async (email) => {
        await sendPasswordResetEmail(getFirebaseAuth(), email.trim());
      },
      sendPhoneCode: async (phone, recaptchaId) => {
        return sendPhoneVerificationCode(getFirebaseAuth(), phone, recaptchaId);
      },
      confirmPhoneCode: async (verificationId, code) => {
        await confirmPhoneVerificationCode(getFirebaseAuth(), verificationId, code);
      },
      logout: async () => {
        await signOut(getFirebaseAuth());
      },
      refreshProfile: async () => {
        const current = getFirebaseAuth().currentUser;
        if (!current) {
          setProfile(null);
          setIsPlatformAdmin(false);
          return;
        }
        const adminInfo = await getPlatformAdminInfo(current.uid);
        setIsPlatformAdmin(adminInfo.isPlatformAdmin);
        let nextProfile = await getUserProfile(current.uid);
        if (adminInfo.isPlatformAdmin && nextProfile && !nextProfile.onboardingCompleted) {
          nextProfile = { ...nextProfile, onboardingCompleted: true };
        }
        setProfile(nextProfile);
      },
    }),
    [user, profile, isPlatformAdmin, loading],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
