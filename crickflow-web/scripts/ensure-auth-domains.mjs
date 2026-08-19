import fs from "node:fs";
import path from "node:path";

const PROJECT_ID = "crickflow-b06bc";
const FIREBASE_OAUTH_CLIENT_ID =
  "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com";
const FIREBASE_OAUTH_CLIENT_SECRET = "jEQC95AvqxBhJcEJgfUfghi7";
const REQUIRED_DOMAINS = [
  "localhost",
  "crickflow-b06bc.firebaseapp.com",
  "crickflow-b06bc.web.app",
  "crickflow.web.app",
  "crickflow.firebaseapp.com",
];

const cfg = JSON.parse(
  fs.readFileSync(
    path.join(process.env.USERPROFILE ?? "", ".config/configstore/firebase-tools.json"),
    "utf8",
  ),
);

async function getAccessToken() {
  const tokens = cfg.tokens ?? {};
  if (tokens.access_token && tokens.expires_at && Date.now() < tokens.expires_at - 60_000) {
    return tokens.access_token;
  }
  const body = new URLSearchParams({
    client_id: tokens.client_id || FIREBASE_OAUTH_CLIENT_ID,
    client_secret: tokens.client_secret || FIREBASE_OAUTH_CLIENT_SECRET,
    refresh_token: tokens.refresh_token,
    grant_type: "refresh_token",
  });
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
    signal: AbortSignal.timeout(60_000),
  });
  if (!res.ok) throw new Error(`Token refresh failed (${res.status})`);
  return (await res.json()).access_token;
}

async function google(accessToken, method, url, jsonBody) {
  const res = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
      "x-goog-user-project": PROJECT_ID,
    },
    body: jsonBody ? JSON.stringify(jsonBody) : undefined,
    signal: AbortSignal.timeout(60_000),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`${method} ${url} -> ${res.status} ${text.slice(0, 500)}`);
  return text ? JSON.parse(text) : {};
}

const accessToken = await getAccessToken();
try {
  await google(
    accessToken,
    "POST",
    `https://serviceusage.googleapis.com/v1/projects/${PROJECT_ID}/services/identitytoolkit.googleapis.com:enable`,
    {},
  );
} catch {
  // already enabled
}

const urls = [
  `https://identitytoolkit.googleapis.com/admin/v2/projects/${PROJECT_ID}/config`,
  `https://identitytoolkit.googleapis.com/v2/projects/${PROJECT_ID}/config`,
];

let current = null;
let configUrl = urls[0];
for (const url of urls) {
  try {
    current = await google(accessToken, "GET", url);
    configUrl = url;
    break;
  } catch {
    current = null;
  }
}

if (!current) {
  throw new Error("Could not read Identity Platform config. Add authorized domains in Firebase Console.");
}

const existing = Array.isArray(current.authorizedDomains) ? current.authorizedDomains : [];
const merged = [...new Set([...existing, ...REQUIRED_DOMAINS])];
const added = merged.filter((domain) => !existing.includes(domain));
if (added.length === 0) {
  console.log(`Authorized domains already include: ${REQUIRED_DOMAINS.join(", ")}`);
} else {
  await google(accessToken, "PATCH", `${configUrl}?updateMask=authorizedDomains`, {
    authorizedDomains: merged,
  });
  console.log(`Added authorized domains: ${added.join(", ")}`);
}
console.log(`Current domains: ${merged.join(", ")}`);
