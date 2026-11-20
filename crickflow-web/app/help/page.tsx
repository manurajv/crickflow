import type { Metadata } from "next";
import { HelpPage } from "@/features/help/help-page";

export const metadata: Metadata = {
  title: "CrickFlow Help",
  description: "Contact CrickFlow by email, phone, or WhatsApp, or chat with staff.",
};

export default function Page() {
  return <HelpPage />;
}
