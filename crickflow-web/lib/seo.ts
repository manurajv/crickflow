import type { Metadata } from "next";
import { siteConfig } from "@/config/site";

export function entityMetadata(options: {
  title: string;
  description: string;
  path: string;
  image?: string;
}): Metadata {
  const url = `${siteConfig.url}${options.path}`;
  return {
    title: `${options.title} · ${siteConfig.name}`,
    description: options.description,
    alternates: { canonical: url },
    openGraph: {
      title: options.title,
      description: options.description,
      url,
      siteName: siteConfig.name,
      type: "website",
      images: [{ url: options.image || siteConfig.logoUrl, alt: options.title }],
    },
    twitter: {
      card: "summary_large_image",
      title: options.title,
      description: options.description,
      images: [options.image || siteConfig.logoUrl],
    },
  };
}
