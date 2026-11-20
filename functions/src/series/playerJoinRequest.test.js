const { test } = require('node:test');
const assert = require('node:assert/strict');
const {
  JOIN_COOLDOWN_MS,
  playerJoinApprovalId,
  hasClientRegistrationPayload,
  latestSubmitTime,
  formatCooldownMessage,
  cooldownFrom,
  mergeDuplicateJoinPlan,
  storagePathFromUrl,
  unusedMediaUrls,
} = require('./playerJoinRequest');

test('playerJoinApprovalId is stable and path-safe', () => {
  assert.equal(playerJoinApprovalId('club1', 'user9'), 'pj_club1_user9');
  assert.equal(playerJoinApprovalId('a/b', 'u\\v'), 'pj_a_b_u_v');
});

test('hasClientRegistrationPayload ignores official identity-only payloads', () => {
  assert.equal(hasClientRegistrationPayload({
    seriesId: 's1',
    clubId: 'c1',
    registrationId: 'reg1',
    displayName: 'Ada',
    fullName: 'Ada',
    crickFlowPlayerId: 'CF1',
  }), false);
  assert.equal(hasClientRegistrationPayload({
    nationalIdDocUrl: 'https://x/doc.jpg',
  }), true);
  assert.equal(hasClientRegistrationPayload({
    customFields: { Guardian: 'Pat' },
  }), true);
});

test('cooldown blocks within 24 hours and explains the remaining time', () => {
  const now = Date.parse('2026-11-20T10:00:00.000Z');
  const last = now - (5 * 60 * 60 * 1000) - (12 * 60 * 1000);
  const result = cooldownFrom(last, now);
  assert.equal(result.blocked, true);
  assert.equal(result.details.code, 'join-cooldown');
  assert.match(result.message, /18 hours and 48 minutes/);
  assert.equal(cooldownFrom(now - JOIN_COOLDOWN_MS, now).blocked, false);
  assert.equal(cooldownFrom(0, now).blocked, false);
  assert.equal(
    formatCooldownMessage(90 * 1000),
    'You can submit another request to this team in 2 minutes.',
  );
});

test('mergeDuplicateJoinPlan keeps the newest and lists older duplicates', () => {
  const plan = mergeDuplicateJoinPlan([
    { id: 'old', status: 'pending', submittedAt: '2026-11-18T00:00:00.000Z' },
    { id: 'newer', status: 'rejected', submittedAt: '2026-11-19T00:00:00.000Z' },
    { id: 'oldest', status: 'pending', requestedAt: '2026-11-17T00:00:00.000Z' },
  ]);
  assert.equal(plan.keep.id, 'newer');
  assert.deepEqual(plan.duplicates.map((d) => d.id), ['old', 'oldest']);
});

test('latestSubmitTime prefers submittedAt over requestedAt', () => {
  assert.equal(
    latestSubmitTime({
      requestedAt: '2026-11-18T00:00:00.000Z',
      submittedAt: '2026-11-19T12:00:00.000Z',
    }),
    Date.parse('2026-11-19T12:00:00.000Z'),
  );
});

test('storagePathFromUrl reads Firebase, GCS, and gs paths', () => {
  const enc = 'https://firebasestorage.googleapis.com/v0/b/b/o/series%2Fs1%2Fregistrations%2Fu9%2Fdoc_u9_1.jpg?alt=media&token=abc';
  assert.equal(storagePathFromUrl(enc), 'series/s1/registrations/u9/doc_u9_1.jpg');
  assert.equal(
    storagePathFromUrl('gs://bucket/series/s1/clubs/c2/registrations/u9/photo_u9_1.jpg'),
    'series/s1/clubs/c2/registrations/u9/photo_u9_1.jpg',
  );
  assert.equal(
    storagePathFromUrl('https://storage.googleapis.com/bucket/series/s1/registrations/u9/doc.jpg?X-Goog-Signature=1'),
    'series/s1/registrations/u9/doc.jpg',
  );
  assert.equal(storagePathFromUrl(''), '');
});

test('unusedMediaUrls returns previous documents that were replaced', () => {
  const unused = unusedMediaUrls(
    { nationalIdDocUrl: 'https://x/old.jpg', passportDocUrl: 'https://x/keep.jpg' },
    { nationalIdDocUrl: 'https://x/new.jpg', passportDocUrl: 'https://x/keep.jpg' },
  );
  assert.deepEqual(unused, ['https://x/old.jpg']);
});
