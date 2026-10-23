"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

/** Alias for mobile "My Cricket" entry → web profile hub. */
export default function MyCricketAlias() {
  const router = useRouter();
  useEffect(() => {
    router.replace("/profile/");
  }, [router]);
  return <p>Opening My Cricket…</p>;
}
