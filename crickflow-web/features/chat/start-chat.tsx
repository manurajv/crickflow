"use client";

import { useState } from "react";
import { AppLink as Link } from "@/components/shared/app-link";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { useAuth } from "@/features/auth/auth-provider";
import { openOrCreateChat } from "@/repositories";

export function StartChatButton({
  otherId,
  otherName,
  otherPhotoUrl,
  otherPlayerId,
}: {
  otherId?: string;
  otherName: string;
  otherPhotoUrl?: string;
  otherPlayerId?: string;
}) {
  const { user, profile } = useAuth();
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  if (!otherId || user?.uid === otherId) return null;
  if (!user) {
    return (
      <Button variant="outline" asChild>
        <Link href="/login">Sign in to message</Link>
      </Button>
    );
  }
  return (
    <Button
      variant="outline"
      disabled={busy}
      onClick={async () => {
        setBusy(true);
        try {
          const chatId = await openOrCreateChat(
            {
              id: user.uid,
              name: profile?.displayName || profile?.name || user.displayName || "CrickFlow user",
              photoUrl: profile?.photoUrl || user.photoURL || undefined,
              playerId: profile?.playerId,
            },
            {
              id: otherId,
              name: otherName,
              photoUrl: otherPhotoUrl,
              playerId: otherPlayerId,
            },
          );
          router.push(`/chat/${chatId}`);
        } catch (error) {
          toast.error(error instanceof Error ? error.message : "Could not start chat");
        } finally {
          setBusy(false);
        }
      }}
    >
      Message
    </Button>
  );
}
