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
    background_color: "#0a0e17",
    theme_color: "#1e88e5",
    icons: [
      {
        src: siteConfig.logoUrl,
        sizes: "192x192",
        type: "image/png",
      },
    ],
  };
}
