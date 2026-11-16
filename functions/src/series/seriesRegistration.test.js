const { test } = require('node:test');
const assert = require('node:assert/strict');
const {
  normalizeSeriesSettings,
  missingRegistrationFields,
  isAllowedRegistrationMediaUrl,
  invalidRegistrationMediaUrls,
  applyOfficialIdentity,
  registrationFieldLabel,
} = require('./seriesRegistration');

test('normalizeSeriesSettings applies defaults and new document flags', () => {
  const s = normalizeSeriesSettings({
    maxSquadSize: 18,
    requireNationalId: 1,
    requireNationalIdDocument: true,
    customRequiredFields: ['  Guardian name ', 'guardian name', 'x', 'School'],
  });
  assert.equal(s.maxSquadSize, 18);
  assert.equal(s.requireFullName, true);
  assert.equal(s.requireNationalId, true);
  assert.equal(s.requireNationalIdDocument, true);
  assert.equal(s.requirePassportDocument, false);
  assert.deepEqual(s.customRequiredFields, ['Guardian name', 'School']);
});

test('missingRegistrationFields includes ID document uploads and custom fields', () => {
  const settings = normalizeSeriesSettings({
    requireFullName: true,
    requireCrickFlowPlayerId: false,
    requireNationalId: true,
    requireNationalIdDocument: true,
    requirePassportDocument: true,
    customRequiredFields: ['Guardian name'],
  });
  assert.deepEqual(
    missingRegistrationFields(settings, { fullName: 'A' }),
    ['nationalId', 'nationalIdDocUrl', 'passportDocUrl', 'Guardian name'],
  );
  assert.deepEqual(
    missingRegistrationFields(settings, {
      fullName: 'A',
      nationalId: 'N1',
      nationalIdDocUrl: 'https://x/n.jpg',
      passportDocUrl: 'https://x/p.jpg',
      customFields: { 'Guardian name': 'Pat' },
    }),
    [],
  );
});

test('isAllowedRegistrationMediaUrl restricts to org + subject paths', () => {
  const ctx = { seriesId: 's1', subjectUserId: 'u9', clubId: 'c2' };
  const okClub = 'https://firebasestorage.googleapis.com/v0/b/b/o/series%2Fs1%2Fclubs%2Fc2%2Fregistrations%2Fu9%2Fdoc_u9_1.jpg?alt=media';
  const okLegacy = 'https://x/o/series%2Fs1%2Fdoc_u9_99.jpg?alt=media';
  const otherUser = 'https://x/o/series%2Fs1%2Fclubs%2Fc2%2Fregistrations%2Fu8%2Fdoc_u8_1.jpg';
  const otherSeries = 'https://x/o/series%2Fs2%2Fregistrations%2Fu9%2Fdoc_u9_1.jpg';
  assert.equal(isAllowedRegistrationMediaUrl('', ctx), true);
  assert.equal(isAllowedRegistrationMediaUrl(okClub, ctx), true);
  assert.equal(isAllowedRegistrationMediaUrl(okLegacy, ctx), true);
  assert.equal(isAllowedRegistrationMediaUrl(otherUser, ctx), false);
  assert.equal(isAllowedRegistrationMediaUrl(otherSeries, ctx), false);
  assert.deepEqual(
    invalidRegistrationMediaUrls({ nationalIdDocUrl: otherUser }, ctx),
    ['nationalIdDocUrl'],
  );
});

test('applyOfficialIdentity reuses the player profile photo when none is uploaded', () => {
  const applied = applyOfficialIdentity(
    { profilePhotoUrl: '' },
    { displayName: 'Mavixas', playerId: 'CF000002', photoUrl: 'https://cdn.example/users/u9.jpg' },
  );
  assert.equal(applied.fullName, 'Mavixas');
  assert.equal(applied.crickFlowPlayerId, 'CF000002');
  assert.equal(applied.profilePhotoUrl, 'https://cdn.example/users/u9.jpg');
});

test('an official profile photo is allowed even when it is not under the org path', () => {
  const profile = { photoUrl: 'https://cdn.example/users/u9.jpg' };
  const ctx = { seriesId: 's1', subjectUserId: 'u9', clubId: 'c2', profile };
  assert.deepEqual(
    invalidRegistrationMediaUrls({ profilePhotoUrl: profile.photoUrl }, ctx),
    [],
  );
  assert.deepEqual(
    invalidRegistrationMediaUrls({ profilePhotoUrl: 'https://cdn.example/users/other.jpg' }, ctx),
    ['profilePhotoUrl'],
  );
});

test('registrationFieldLabel never exposes internal field keys', () => {
  assert.equal(registrationFieldLabel('profilePhotoUrl'), 'Profile photo');
  assert.equal(registrationFieldLabel('nationalIdDocUrl'), 'National ID document');
  assert.equal(registrationFieldLabel('passportDocUrl'), 'Passport document');
});
