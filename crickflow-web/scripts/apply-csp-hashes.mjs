#!/usr/bin/env node
/**
 * After `next build`, hash inline scripts in `out HTML files` and write a
 * Hosting config whose default CSP drops script 'unsafe-inline' / 'unsafe-eval'.
 * Phone-auth routes keep a looser policy for reCAPTCHA.
 */
import { createHash } from "node:crypto";
import { existsSync, readFileSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(fileURLToPath(import.meta.url));
const webRoot = join(root, "..");
const outDir = join(webRoot, "out");
const srcConfig = join(webRoot, "firebase.json");
const destConfig = join(webRoot, ".firebase-hosting.generated.json");

function walk(dir, acc = []) {
  for (const name of readdirSync(dir)) {
    const full = join(dir, name);
    const st = statSync(full);
    if (st.isDirectory()) walk(full, acc);
    else acc.push(full);
  }
  return acc;
}

function inlineScripts(html) {
  const out = [];
  const re = /<script\b([^>]*)>([\s\S]*?)<\/script>/gi;
  let m;
  while ((m = re.exec(html))) {
    const attrs = m[1] || "";
    if (/\bsrc\s*=/i.test(attrs)) continue;
    out.push(m[2] || "");
  }
  return out;
}

function sha256(content) {
  return `sha256-${createHash("sha256").update(content, "utf8").digest("base64")}`;
}

if (!existsSync(outDir) || !statSync(outDir).isDirectory()) {
  console.error("apply-csp-hashes: missing out/ — run next build first");
  process.exit(1);
}

const files = walk(outDir).filter((f) => f.endsWith(".html"));
const hashes = new Set();
for (const file of files) {
  const html = readFileSync(file, "utf8");
  for (const script of inlineScripts(html)) {
    hashes.add(`'${sha256(script)}'`);
  }
}
const hashList = [...hashes].sort();
if (hashList.length === 0) {
  console.warn("apply-csp-hashes: no inline scripts found");
}

const config = JSON.parse(readFileSync(srcConfig, "utf8"));
const headers = config.hosting?.headers;
if (!Array.isArray(headers)) {
  console.error("apply-csp-hashes: firebase.json hosting.headers missing");
  process.exit(1);
}

const global = headers.find((h) => h.source === "**");
const csp = global?.headers?.find((h) => h.key === "Content-Security-Policy");
if (!csp) {
  console.error("apply-csp-hashes: default CSP header missing");
  process.exit(1);
}

const defaultScriptSrc =
  "script-src 'self' " +
  hashList.join(" ") +
  (hashList.length ? " " : "") +
  "https://www.googletagmanager.com https://www.google.com https://www.gstatic.com https://www.recaptcha.net https://apis.google.com https://www.google-analytics.com";

const looseScriptSrc =
  "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://www.googletagmanager.com https://www.google.com https://www.gstatic.com https://www.recaptcha.net https://apis.google.com https://www.google-analytics.com";

if (!csp.value.includes("script-src ")) {
  console.error("apply-csp-hashes: script-src not found in CSP");
  process.exit(1);
}
csp.value = csp.value.replace(/script-src [^;]+/, defaultScriptSrc);
if (csp.value.includes("'unsafe-inline'") || csp.value.includes("'unsafe-eval'")) {
  // style-src may still have unsafe-inline; that is OK. script-src must not.
  const scriptPart = csp.value.match(/script-src [^;]+/)?.[0] || "";
  if (scriptPart.includes("'unsafe-inline'") || scriptPart.includes("'unsafe-eval'")) {
    console.error("apply-csp-hashes: failed to strip script unsafe sources");
    process.exit(1);
  }
}

const looseCsp = csp.value.replace(/script-src [^;]+/, looseScriptSrc);
const authSources = [
  "/login/",
  "/login/**",
  "/register/",
  "/register/**",
  "/invite/**",
];
const existing = new Set(headers.map((h) => h.source));
for (const source of authSources) {
  const header = {
    source,
    headers: [{ key: "Content-Security-Policy", value: looseCsp }],
  };
  if (existing.has(source)) {
    const idx = headers.findIndex((h) => h.source === source);
    const list = headers[idx].headers || [];
    const found = list.find((h) => h.key === "Content-Security-Policy");
    if (found) found.value = looseCsp;
    else list.push({ key: "Content-Security-Policy", value: looseCsp });
    headers[idx].headers = list;
  } else {
    headers.push(header);
  }
}

writeFileSync(destConfig, JSON.stringify(config, null, 2) + "\n");
console.log(
  `apply-csp-hashes: ${hashList.length} unique inline script hashes from ${files.length} html files`,
);
console.log(`wrote ${relative(webRoot, destConfig)}`);
