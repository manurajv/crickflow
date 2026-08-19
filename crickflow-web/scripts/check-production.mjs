import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const WEB_HOSTING_SITE = "crickflow";
const webRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const pkg = JSON.parse(fs.readFileSync(path.join(webRoot, "package.json"), "utf8"));
const firebase = JSON.parse(fs.readFileSync(path.join(webRoot, "firebase.json"), "utf8"));
const parentFirebase = path.join(webRoot, "..", "firebase.json");

if (pkg.name !== "crickflow-web") {
  console.error("Production gate: package name must be crickflow-web.");
  process.exit(1);
}

if (firebase.hosting?.public !== "out" || firebase.hosting?.source) {
  console.error("Production gate: crickflow-web must deploy static `out/` to site crickflow, never SSR onto the mobile Hosting site.");
  process.exit(1);
}

if (firebase.hosting.site !== WEB_HOSTING_SITE) {
  console.error(`Production gate: firebase.json must target site ${WEB_HOSTING_SITE}, never the mobile Hosting site.`);
  process.exit(1);
}

if (!fs.existsSync(parentFirebase)) {
  console.error("Production gate: expected a parent firebase.json (mobile App Links). Refusing to continue.");
  process.exit(1);
}

const parent = JSON.parse(fs.readFileSync(parentFirebase, "utf8"));
if (parent.hosting?.site === WEB_HOSTING_SITE || parent.hosting?.source) {
  console.error("Production gate: repo-root firebase.json must stay on the mobile Hosting site.");
  process.exit(1);
}

const siteUrl = process.env.NEXT_PUBLIC_SITE_URL ?? "https://crickflow.web.app";
if (!siteUrl.startsWith("https://")) {
  console.error("Production gate: NEXT_PUBLIC_SITE_URL must be https.");
  process.exit(1);
}

console.log(`Production gate OK — isolated ${WEB_HOSTING_SITE} config; root Hosting untouched.`);
