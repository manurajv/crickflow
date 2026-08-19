import { ChatConversationClient } from "./chat-conversation-client";
import { shellParams } from "@/lib/static-params";

export function generateStaticParams() {
  return shellParams("id");
}

export default function ChatConversationPage() {
  return <ChatConversationClient />;
}
