#!/usr/bin/env node
/**
 * Optional CI → Firestore metadata writer for DevOps Center.
 *
 * Writes ONLY non-secret build/deploy metadata into:
 *   admin_devops_builds/{id}
 *   admin_devops_timeline/{id}
 *
 * Required env:
 *   GOOGLE_APPLICATION_CREDENTIALS_JSON  — service account JSON string (Actions secret)
 *   ADMIN_VERSION, ADMIN_BUILD_NUMBER, GIT_SHA, GIT_REF, WORKFLOW_URL
 *
 * Enable with repository variable ADMIN_CI_METADATA_ENABLED=true
 *
 * Never logs the service account contents.
 */
'use strict';

const { createHash } = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');

async function main() {
  const json = process.env.GOOGLE_APPLICATION_CREDENTIALS_JSON;
  if (!json) {
    console.log('Skipping: GOOGLE_APPLICATION_CREDENTIALS_JSON not set');
    return;
  }

  let admin;
  try {
    admin = require('firebase-admin');
  } catch {
    console.error('Install firebase-admin in CI before enabling metadata publish:');
    console.error('  npm install firebase-admin');
    process.exit(1);
  }

  const tmp = path.join(os.tmpdir(), `cf-sa-${process.pid}.json`);
  fs.writeFileSync(tmp, json, { mode: 0o600 });
  process.env.GOOGLE_APPLICATION_CREDENTIALS = tmp;

  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
    });
  }

  const db = admin.firestore();
  const version = process.env.ADMIN_VERSION || '0.0.0';
  const buildNumber = process.env.ADMIN_BUILD_NUMBER || '0';
  const sha = process.env.GIT_SHA || '';
  const ref = process.env.GIT_REF || '';
  const workflowUrl = process.env.WORKFLOW_URL || '';
  const id = createHash('sha1')
    .update(`${sha}-${buildNumber}-${version}`)
    .digest('hex')
    .slice(0, 20);

  const buildDoc = {
    label: `CI build ${version}+${buildNumber}`,
    status: 'success',
    environment: 'staging',
    version,
    buildNumber: String(buildNumber),
    gitSha: sha,
    gitRef: ref,
    workflowUrl,
    source: 'github_actions',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await db.collection('admin_devops_builds').doc(id).set(buildDoc, { merge: true });
  await db.collection('admin_devops_timeline').doc(`ci_${id}`).set(
    {
      kind: 'buildCompleted',
      title: `CI build ${version}+${buildNumber}`,
      subtitle: ref,
      environment: 'staging',
      meta: { gitSha: sha, workflowUrl },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  console.log(`Published CI metadata build id=${id} version=${version}+${buildNumber}`);
  try {
    fs.unlinkSync(tmp);
  } catch (_) {
    /* ignore */
  }
}

main().catch((err) => {
  console.error('publish-admin-ci-metadata failed:', err && err.message ? err.message : err);
  process.exit(1);
});
