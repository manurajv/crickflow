import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const webRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const outDir = path.join(webRoot, "out");
if (!fs.existsSync(outDir)) {
  console.error("Built-env gate: out/ is missing. Run npm run build first.");
  process.exit(1);
}

function walk(dir, acc = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(p, acc);
    else if (entry.name.endsWith(".js")) acc.push(p);
  }
  return acc;
}

const files = walk(path.join(outDir, "_next"));
let foundKey = false;
let foundAuthDomain = false;
let leftoverEnvRef = false;
for (const file of files) {
  const text = fs.readFileSync(file, "utf8");
  if (/AIza[0-9A-Za-z_-]{20,}/.test(text)) foundKey = true;
  if (text.includes("crickflow-b06bc.firebaseapp.com")) foundAuthDomain = true;
  if (text.includes("env.NEXT_PUBLIC_FIREBASE_API_KEY")) leftoverEnvRef = true;
}

if (!foundKey || !foundAuthDomain || leftoverEnvRef) {
  console.error(
    "Built-env gate failed:",
    JSON.stringify({ foundKey, foundAuthDomain, leftoverEnvRef }),
  );
  console.error(
    "The static export must inline the public Firebase web API key and auth domain. Copy .env.example to .env.production or .env.local before building.",
  );
  process.exit(1);
}
console.log("Built-env gate OK — Firebase web API key and auth domain are inlined.");
