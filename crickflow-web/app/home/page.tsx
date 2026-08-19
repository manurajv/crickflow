"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

export default function HomeAlias() {
  const router = useRouter();
  useEffect(() => {
    router.replace("/");
  }, [router]);
  return <p>Redirecting to home…</p>;
}
