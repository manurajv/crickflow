"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

/** Legacy mobile alias — the website profile is the destination. */
export default function MyCricketProfileAlias() {
  const router = useRouter();
  useEffect(() => {
    router.replace("/profile/");
  }, [router]);
  return <p>Taking you to your profile…</p>;
}
