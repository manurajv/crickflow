"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

/** My Cricket is no longer a website destination — send people to their profile. */
export default function MyCricketRedirect() {
  const router = useRouter();
  useEffect(() => {
    router.replace("/profile/");
  }, [router]);
  return <p>Taking you to your profile…</p>;
}
