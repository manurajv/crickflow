import fs from "node:fs";
import path from "node:path";

const PROJECT_ID = "crickflow-b06bc";
const PROJECT_NUMBER = "202403125129";
const FIREBASE_OAUTH_CLIENT_ID =
  "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com";
const FIREBASE_OAUTH_CLIENT_SECRET = "jEQC95AvqxBhJcEJgfUfghi7";

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
  if (!res.ok) {
    throw new Error(`Token refresh failed (${res.status})`);
  }
  const json = await res.json();
  return json.access_token;
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
  if (!res.ok) {
    throw new Error(`${method} ${url} -> ${res.status} ${text.slice(0, 400)}`);
  }
  return text ? JSON.parse(text) : {};
}

const services = [
  "cloudfunctions.googleapis.com",
  "cloudbuild.googleapis.com",
  "artifactregistry.googleapis.com",
  "run.googleapis.com",
  "eventarc.googleapis.com",
  "pubsub.googleapis.com",
  "storage.googleapis.com",
  "firebaseextensions.googleapis.com",
];

const identities = ["pubsub.googleapis.com", "eventarc.googleapis.com"];

const accessToken = await getAccessToken();
for (const service of services) {
  process.stdout.write(`enable ${service} ... `);
  try {
    await google(
      accessToken,
      "POST",
      `https://serviceusage.googleapis.com/v1/projects/${PROJECT_ID}/services/${service}:enable`,
      {},
    );
    console.log("ok");
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    if (/already enabled|FAILED_PRECONDITION|409/i.test(message)) console.log("already enabled");
    else console.log(message);
  }
}

for (const service of identities) {
  process.stdout.write(`identity ${service} ... `);
  try {
    await google(
      accessToken,
      "POST",
      `https://serviceusage.googleapis.com/v1beta1/projects/${PROJECT_NUMBER}/services/${service}:generateServiceIdentity`,
      {},
    );
    console.log("ok");
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    if (/already exists|409/i.test(message)) console.log("exists");
    else console.log(message);
  }
}
