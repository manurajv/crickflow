import type { MetadataRoute } from "next";
import { siteConfig } from "@/config/site";

export const dynamic = "force-static";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: siteConfig.name,
    short_name: siteConfig.name,
    description: siteConfig.description,
    start_url: "/",
    display: "standalone",
    background_color: "#f4f6f8",
    theme_color: "#1565c0",
    icons: [
      {
        src: siteConfig.logoUrl,
        sizes: "192x192",
        type: "image/png",
      },
    ],
  };
}
