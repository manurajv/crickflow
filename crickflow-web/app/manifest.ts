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
        src: siteConfig.icons.icon192,
        sizes: "192x192",
        type: "image/png",
      },
      {
        src: siteConfig.icons.icon512,
        sizes: "512x512",
        type: "image/png",
      },
      {
        src: siteConfig.icons.apple,
        sizes: "180x180",
        type: "image/png",
      },
    ],
  };
}
