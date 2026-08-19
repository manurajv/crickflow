"use client";

import { useEffect, useState } from "react";
import { useAuth } from "@/features/auth/auth-provider";
import { watchBlockedUserIds } from "@/repositories";

export function useBlockedUserIds() {
  const { user } = useAuth();
  const [ids, setIds] = useState<Set<string>>(new Set());

  useEffect(() => {
    if (!user) return;
    return watchBlockedUserIds(user.uid, setIds);
  }, [user]);

  return ids;
}
