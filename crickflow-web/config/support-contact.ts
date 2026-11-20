/** Public CrickFlow Help contact details (same values as the mobile app). */
export const supportContact = {
  emails: ["mavixas.ceo@gmail.com", "crickflow.app@gmail.com"] as const,
  phoneE164: "+94701036188",
  phoneDisplay: "+94 70 103 6188",
  whatsappUrl: "https://wa.me/94701036188",
  tel: "tel:+94701036188",
} as const;

export function mailto(email: string) {
  return `mailto:${email}`;
}
