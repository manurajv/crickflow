"use client";

import {
  GoogleAuthProvider,
  RecaptchaVerifier,
  createUserWithEmailAndPassword,
  getRedirectResult,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signInWithPhoneNumber,
  signInWithPopup,
  signInWithRedirect,
  signOut,
  type User,
} from "firebase/auth";
import { createContext, useContext, useEffect, useMemo, useState } from "react";
import { getFirebaseAuth, isFirebaseConfigured } from "@/lib/firebase/client";
import { getUserProfile, upsertUserProfile } from "@/repositories";
import type { UserProfile } from "@/types/models";

interface AuthContextValue {
  user: User | null;
  profile: UserProfile | null;
  loading: boolean;
  signInGoogle: () => Promise<void>;
  signInEmail: (email: string, password: string) => Promise<void>;
  registerEmail: (email: string, password: string) => Promise<void>;
  sendPhoneCode: (phone: string, recaptchaId: string) => Promise<string>;
  confirmPhoneCode: (verificationId: string, code: string) => Promise<void>;
  logout: () => Promise<void>;
  refreshProfile: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(() => isFirebaseConfigured());

  useEffect(() => {
    if (!isFirebaseConfigured()) {
      return;
    }
    const auth = getFirebaseAuth();
    void getRedirectResult(auth).catch(() => undefined);
    const unsub = onAuthStateChanged(auth, async (next) => {
      setUser(next);
      if (!next) {
        setProfile(null);
        setLoading(false);
        return;
      }
      try {
        let existing = await getUserProfile(next.uid);
        if (!existing) {
          await upsertUserProfile({
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
            onboardingCompleted: false,
          });
          existing = await getUserProfile(next.uid);
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
      sendPhoneCode: async (phone, recaptchaId) => {
        const auth = getFirebaseAuth();
        const verifier = new RecaptchaVerifier(auth, recaptchaId, { size: "invisible" });
        const confirmation = await signInWithPhoneNumber(auth, phone, verifier);
        return confirmation.verificationId;
      },
      confirmPhoneCode: async (verificationId, code) => {
        const { PhoneAuthProvider, signInWithCredential } = await import("firebase/auth");
        const credential = PhoneAuthProvider.credential(verificationId, code);
        await signInWithCredential(getFirebaseAuth(), credential);
      },
      logout: async () => {
        await signOut(getFirebaseAuth());
      },
      refreshProfile: async () => {
        const current = getFirebaseAuth().currentUser;
        if (!current) {
          setProfile(null);
          return;
        }
        setProfile(await getUserProfile(current.uid));
      },
    }),
    [user, profile, loading],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
