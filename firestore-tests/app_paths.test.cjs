/* eslint-disable */
// App path audit (t49): every client read/write shape used by the mobile app,
// crickflow-web and the superadmin panel that touches a non-public rule, run as
// the role that performs it in the app. `allow(...)` = must succeed,
// `deny(...)` = must stay blocked (privacy).
const { test, before, after } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment, assertSucceeds, assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc, setDoc, getDoc, getDocs, updateDoc, deleteDoc, collection, collectionGroup,
  query, where, orderBy, limit, writeBatch, runTransaction, arrayUnion, arrayRemove, deleteField,
} = require('firebase/firestore');

let env;
const NOW = '2026-11-14T10:00:00.000Z';
const anon = () => env.unauthenticatedContext().firestore();
const as = (uid) => env.authenticatedContext(uid).firestore();
const allow = (name, fn) => test(`allow: ${name}`, async () => { await assertSucceeds(fn()); });
const deny = (name, fn) => test(`deny: ${name}`, async () => { await assertFails(fn()); });

const ALLP = ['canManageTeams', 'canManageTournaments', 'canManageOrganizations', 'canManageMatches',
  'canModerateCommunity', 'canSendNotifications', 'canManageUsers', 'canManageSecurity', 'canViewLogs'];

before(async () => {
  const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080').split(':');
  env = await initializeTestEnvironment({
    projectId: process.env.GCLOUD_PROJECT || 'demo-crickflow-rules',
    firestore: { rules: fs.readFileSync(process.env.RULES_FILE || path.join(__dirname, '..', 'firestore.rules'), 'utf8'), host, port: Number(port) },
  });
  await env.withSecurityRulesDisabled(async (c) => {
    const db = c.firestore();
    const w = (p, d) => setDoc(doc(db, p), d);
    const perms = {}; for (const k of ALLP) perms[k] = true;
    await w('admin_roles/superAdmin', { allowedPanel: 'superAdmin', permissions: perms });
    await w('admin_users/sa', { roleId: 'superAdmin', isActive: true, accessStatus: 'active', email: 'sa@x.test' });
    for (const u of ['owner', 'cap', 'vc', 'mem', 'plain', 'req', 'inv', 'oown', 'oadm', 'oscorer', 'oviewer', 'ocadm', 'sa']) {
      await w(`users/${u}`, { uid: u, name: u, displayName: u, onboardingCompleted: true, createdAt: NOW });
    }
    // Team with owner, captain, vice-captain and a member (player doc id == uid).
    await w('teams/T1', {
      name: 'T1', teamCode: 'TM00001', createdBy: 'owner', captainId: 'cap', viceCaptainId: 'vc',
      playerIds: ['owner', 'cap', 'vc', 'mem'], memberCount: 4, createdAt: NOW, updatedAt: NOW,
    });
    for (const u of ['owner', 'cap', 'vc', 'mem']) {
      await w(`players/${u}`, { name: u, userId: u, teamIds: ['T1'], teamId: 'T1', createdBy: u });
    }
    for (const u of ['plain', 'req', 'inv']) await w(`players/${u}`, { name: u, userId: u, createdBy: u });
    await w('teams/T1/join_requests/req', {
      userId: 'req', playerId: 'req', playerName: 'req', teamId: 'T1', teamName: 'T1',
      requestType: 'join_request', status: 'pending', createdAt: NOW, updatedAt: NOW,
    });
    // Sole-owner team (just created, has a team code, no optional fields).
    await w('teams/SOLO', { name: 'Solo', teamCode: 'TM00002', createdBy: 'plain', playerIds: ['plain'], memberCount: 1, captainId: 'plain', createdAt: NOW });
    await w('teams/SOLO/join_requests/req', {
      userId: 'req', playerId: 'req', playerName: 'req', teamId: 'SOLO', requestType: 'join_request', status: 'pending', createdAt: NOW,
    });
    await w('notifications/n_owner_T1', { userId: 'owner', teamId: 'T1', type: 'team_join_request', addedByUserId: 'req', title: 't', body: 'b', read: false, createdAt: NOW });
    await w('notifications/n_plain_solo', { userId: 'plain', teamId: 'SOLO', type: 'team_join_request', addedByUserId: 'req', title: 't', body: 'b', read: false, createdAt: NOW });
    await w('notifications/n_req_solo', { userId: 'req', teamId: 'SOLO', type: 'team_join_accepted', addedByUserId: 'plain', title: 't', body: 'b', read: false, createdAt: NOW });
    // Org: owner, full admin, scorer, viewer, team (club) admin.
    await w('series/S1', { name: 'Org', kind: 'series', status: 'active', superAdminUserId: 'oown', createdBy: 'oown', createdAt: NOW });
    await w('series_admins/S1_oadm', { seriesId: 'S1', userId: 'oadm', status: 'active', role: 'admin' });
    await w('series_admins/S1_oscorer', { seriesId: 'S1', userId: 'oscorer', status: 'active', role: 'scorer' });
    await w('series_admins/S1_oviewer', { seriesId: 'S1', userId: 'oviewer', status: 'active', role: 'viewer' });
    await w('series_clubs/C1', { seriesId: 'S1', name: 'Club', status: 'approved', createdBy: 'ocadm', createdAt: NOW });
    await w('series_club_admins/S1_C1_ocadm', { seriesId: 'S1', clubId: 'C1', userId: 'ocadm', status: 'active' });
    const appr = { seriesId: 'S1', clubId: 'C1', status: 'pending', targetType: 'playerJoin', requestedBy: 'plain', requestedAt: NOW };
    await w('series/S1/approvals/A1', appr);
    await w('series_approvals/A1', appr);
    await w('series/S1/approvals/A2', { ...appr, clubId: 'C2', requestedBy: 'req' });
    await w('series_registrations/R1', { seriesId: 'S1', clubId: 'C1', userId: 'plain', createdBy: 'plain', status: 'pending', createdAt: NOW });
    await w('series_audit_logs/L1', { seriesId: 'S1', action: 'X', timestamp: NOW });
    await w('series/S1/announcements/AN1', { seriesId: 'S1', title: 'x', createdAt: NOW });
    // Community post by owner with engagement from others.
    await w('community_posts/P1', { authorId: 'owner', title: 't', body: 'b', likeCount: 1, commentCount: 1, saveCount: 1, createdAt: NOW });
    await w('community_posts/P1/likes/plain', { userId: 'plain', createdAt: NOW });
    await w('community_posts/P1/comments/c1', { authorId: 'plain', text: 'hi', createdAt: NOW });
    await w('community_posts/P1/comments/c1/likes/req', { userId: 'req', createdAt: NOW });
    await w('community_posts/P1/saves/plain', { userId: 'plain', createdAt: NOW });
    // Streaming replay markers and fantasy entries (collection-group reads).
    await w('matches/M1', { title: 'M', createdBy: 'owner', status: 'live', createdAt: NOW });
    await w('matches/M1/streamSessions/SS1/replayMarkers/RM1', { matchId: 'M1', streamSessionId: 'SS1', ballEventId: 'b1', kind: 'six', createdAt: NOW });
    await w('matches/M1/replayMarkers/RM0', { matchId: 'M1', createdAt: NOW });
    await w('fantasy_leagues/F1', { name: 'F', createdBy: 'owner', joinCode: 'ABC', status: 'open' });
    await w('fantasy_leagues/F1/entries/E1', { userId: 'plain', totalPoints: 1, updatedAt: NOW });
    await w('fantasy_leagues/F1/entries/E2', { userId: 'req', totalPoints: 2, updatedAt: NOW });
    // Chats
    await w('chats/plain_req', { participantIds: ['plain', 'req'], status: 'active', lastMessageAt: NOW, createdAt: NOW });
    await w('chat_blocks/plain_inv', { blockerId: 'plain', blockedId: 'inv', createdAt: NOW });
    await w('app_meta/platform_admins', { uids: ['sa'] });
  });
});
after(async () => { await env?.cleanup(); });

// ── Team join requests (team page panel) ────────────────────────────────────
const pendingQ = (db, team) => query(collection(db, `teams/${team}/join_requests`), where('status', '==', 'pending'), orderBy('createdAt', 'desc'));
allow('team owner lists pending join requests', () => getDocs(pendingQ(as('owner'), 'T1')));
allow('captain lists pending join requests', () => getDocs(pendingQ(as('cap'), 'T1')));
allow('vice-captain lists pending join requests', () => getDocs(pendingQ(as('vc'), 'T1')));
allow('owner of a just-created team (captain = owner) lists join requests', () => getDocs(pendingQ(as('plain'), 'SOLO')));
allow('owner lists pending invitations (no orderBy)', () => getDocs(query(collection(as('owner'), 'teams/T1/join_requests'), where('status', '==', 'pending'))));
allow('requester reads own request', () => getDoc(doc(as('req'), 'teams/T1/join_requests/req')));
allow('requester checks a team they never asked (missing doc)', () => getDoc(doc(as('inv'), 'teams/T1/join_requests/inv')));
deny('member lists join requests', () => getDocs(pendingQ(as('mem'), 'T1')));
deny('plain user lists join requests', () => getDocs(pendingQ(as('plain'), 'T1')));
deny('guest lists join requests', () => getDocs(pendingQ(anon(), 'T1')));
deny('requester reads another request', () => getDoc(doc(as('inv'), 'teams/T1/join_requests/req')));

allow('user sends a join request', () => setDoc(doc(as('inv'), 'teams/T1/join_requests/inv'), {
  userId: 'inv', playerId: 'inv', playerName: 'inv', teamId: 'T1', teamName: 'T1',
  requestType: 'join_request', status: 'pending', createdAt: NOW, updatedAt: NOW,
}));
allow('captain rejects a join request', () => updateDoc(doc(as('cap'), 'teams/T1/join_requests/req'), {
  status: 'rejected', updatedAt: NOW, resolvedBy: 'cap', resolvedAt: NOW,
}));

// ── Team roster changes ─────────────────────────────────────────────────────
function acceptTx(db, team, player) {
  return runTransaction(db, async (tx) => {
    const t = await tx.get(doc(db, `teams/${team}`));
    await tx.get(doc(db, `players/${player}`));
    const ids = [...t.data().playerIds, player];
    tx.update(doc(db, `players/${player}`), { teamIds: arrayUnion(team), teamId: team, rosterChangeTeamId: team, updatedAt: NOW, teamJoinedAt: NOW });
    tx.update(doc(db, `teams/${team}`), { playerIds: ids, memberCount: ids.length, updatedAt: NOW });
  });
}
allow('owner accepts a join request (assignPlayerToTeam)', () => acceptTx(as('owner'), 'T1', 'req'));
allow('captain adds a player (assignPlayerToTeam)', () => acceptTx(as('cap'), 'T1', 'inv'));
deny('plain user adds themselves to a team roster', () => acceptTx(as('plain'), 'T1', 'plain'));

allow('captain invites a registered player', () => setDoc(doc(as('cap'), 'teams/SOLO/join_requests/inv'), {
  userId: 'inv', playerId: 'inv', playerName: 'inv', teamId: 'SOLO', teamName: 'Solo', requestType: 'invitation',
  invitedByUserId: 'cap', status: 'pending', createdAt: NOW, updatedAt: NOW,
}).catch(() => setDoc(doc(as('plain'), 'teams/SOLO/join_requests/inv'), {
  userId: 'inv', playerId: 'inv', playerName: 'inv', teamId: 'SOLO', teamName: 'Solo', requestType: 'invitation',
  invitedByUserId: 'plain', status: 'pending', createdAt: NOW, updatedAt: NOW,
})));
test('allow: invitee accepts an invitation (joins the roster)', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), 'teams/INV/join_requests/inv'), {
      userId: 'inv', playerId: 'inv', playerName: 'inv', teamId: 'INV', requestType: 'invitation',
      invitedByUserId: 'owner', status: 'pending', createdAt: NOW,
    });
    await setDoc(doc(c.firestore(), 'teams/INV'), { name: 'Inv', teamCode: 'TM00009', createdBy: 'owner', playerIds: ['owner'], memberCount: 1, createdAt: NOW });
  });
  const db = as('inv');
  await assertSucceeds(acceptTx(db, 'INV', 'inv'));
  await assertSucceeds(updateDoc(doc(db, 'teams/INV/join_requests/inv'), { status: 'accepted', updatedAt: NOW, resolvedBy: 'inv', resolvedAt: NOW }));
});

deny('invitee cannot add a different player with their invitation', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), 'teams/INV2'), { name: 'Inv2', teamCode: 'TM00010', createdBy: 'owner', playerIds: ['owner'], memberCount: 1, createdAt: NOW });
    await setDoc(doc(c.firestore(), 'teams/INV2/join_requests/inv'), { userId: 'inv', playerId: 'inv', playerName: 'inv', teamId: 'INV2', requestType: 'invitation', invitedByUserId: 'owner', status: 'pending', createdAt: NOW });
  });
  return updateDoc(doc(as('inv'), 'teams/INV2'), { playerIds: ['owner', 'plain'], memberCount: 2, updatedAt: NOW });
});
deny('invitee cannot remove others from the roster', () => updateDoc(doc(as('inv'), 'teams/INV2'), { playerIds: ['inv'], memberCount: 1, updatedAt: NOW }));
deny('user with a join request (not an invitation) cannot add themselves', () => updateDoc(doc(as('req'), 'teams/SOLO'), { playerIds: ['plain', 'req'], memberCount: 2, updatedAt: NOW }));
function removeTx(db, team, player) {
  return runTransaction(db, async (tx) => {
    const t = await tx.get(doc(db, `teams/${team}`));
    await tx.get(doc(db, `players/${player}`));
    const ids = t.data().playerIds.filter((x) => x !== player);
    tx.update(doc(db, `teams/${team}`), { playerIds: ids, memberCount: ids.length, updatedAt: NOW });
    tx.update(doc(db, `players/${player}`), { teamIds: arrayRemove(team), teamId: deleteField(), teamJoinedAt: deleteField(), rosterChangeTeamId: team, updatedAt: NOW });
  });
}
test('allow: captain and vice-captain remove members; deny removing leaders', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    const db = c.firestore();
    await setDoc(doc(db, 'teams/RM'), { name: 'RM', teamCode: 'TM00011', createdBy: 'owner', captainId: 'cap', viceCaptainId: 'vc', playerIds: ['owner', 'cap', 'vc', 'm1', 'm2'], memberCount: 5, createdAt: NOW });
    for (const u of ['m1', 'm2']) await setDoc(doc(db, `players/${u}`), { name: u, userId: u, teamIds: ['RM'], teamId: 'RM' });
    for (const u of ['owner', 'cap', 'vc']) await updateDoc(doc(db, `players/${u}`), { teamIds: arrayUnion('RM') });
  });
  await assertSucceeds(removeTx(as('cap'), 'RM', 'm1'));
  await assertSucceeds(removeTx(as('vc'), 'RM', 'm2'));
  await assertFails(removeTx(as('cap'), 'RM', 'vc'));
  await assertFails(removeTx(as('vc'), 'RM', 'owner'));
  await assertSucceeds(removeTx(as('owner'), 'RM', 'vc'));
});
test('allow: invitee declines an invitation', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), 'teams/INV2/join_requests/req'), { userId: 'req', playerId: 'req', playerName: 'req', teamId: 'INV2', requestType: 'invitation', invitedByUserId: 'owner', status: 'pending', createdAt: NOW });
  });
  await assertSucceeds(updateDoc(doc(as('req'), 'teams/INV2/join_requests/req'), { status: 'rejected', updatedAt: NOW, resolvedBy: 'req', resolvedAt: NOW }));
});
allow('member leaves the team', () => { const db = as('mem'); return runTransaction(db, async (tx) => {
  const t = await tx.get(doc(db, 'teams/T1'));
  await tx.get(doc(db, 'players/mem'));
  const ids = t.data().playerIds.filter((x) => x !== 'mem');
  tx.update(doc(db, 'teams/T1'), { playerIds: ids, memberCount: ids.length, updatedAt: NOW });
  tx.update(doc(db, 'players/mem'), { teamIds: arrayRemove('T1'), teamId: deleteField(), teamJoinedAt: deleteField(), rosterChangeTeamId: 'T1', updatedAt: NOW });
}); });

test('allow: sole owner leaves → team (with team code) and its requests are deleted', async () => {
  const db = as('plain');
  await assertSucceeds(runTransaction(db, async (tx) => {
    const t = await tx.get(doc(db, 'teams/SOLO'));
    const r = await tx.get(doc(db, 'teams/SOLO/join_requests/req'));
    await tx.get(doc(db, 'players/plain'));
    if (r.exists()) tx.delete(r.ref);
    tx.delete(t.ref);
  }));
  // Own inbox rows about the deleted team (best-effort cleanup).
  const mine = await assertSucceeds(getDocs(query(collection(db, 'notifications'), where('teamId', '==', 'SOLO'), where('userId', '==', 'plain'), limit(100))));
  for (const d of mine.docs) await assertSucceeds(deleteDoc(d.ref));
});
deny('team cleanup cannot read other users\' notifications', () => getDocs(query(collection(as('plain'), 'notifications'), where('teamId', '==', 'SOLO'), limit(100))));

allow('owner edits team details (full toMap update)', () => updateDoc(doc(as('owner'), 'teams/T1'), {
  name: 'T1 renamed', teamCode: 'TM00001', createdBy: 'owner', logoUrl: 'x', updatedAt: NOW,
}));
deny('member edits team details', () => updateDoc(doc(as('vc'), 'teams/T1'), { name: 'hack', teamCode: 'TM00001', createdBy: 'vc' }));

// ── Org (series) reads by role ──────────────────────────────────────────────
const pendingApprovals = (db) => query(collection(db, 'series/S1/approvals'), where('status', '==', 'pending'), orderBy('requestedAt', 'desc'));
const clubApprovals = (db, club) => query(collection(db, 'series/S1/approvals'), where('clubId', '==', club), where('status', '==', 'pending'));
for (const u of ['oown', 'oadm', 'oscorer', 'oviewer', 'sa']) allow(`org staff ${u} lists pending approvals`, () => getDocs(pendingApprovals(as(u))));
allow('org team admin lists own team\'s pending join approvals', () => getDocs(clubApprovals(as('ocadm'), 'C1')));
deny('org team admin lists another team\'s approvals', () => getDocs(clubApprovals(as('ocadm'), 'C2')));
deny('plain user lists org approvals', () => getDocs(pendingApprovals(as('plain'))));
deny('guest lists org approvals', () => getDocs(pendingApprovals(anon())));
allow('requester lists own approvals', () => getDocs(query(collection(as('plain'), 'series_approvals'), where('seriesId', '==', 'S1'), where('requestedBy', '==', 'plain'))));
const regs = (db, extra = []) => query(collection(db, 'series_registrations'), where('seriesId', '==', 'S1'), ...extra, orderBy('createdAt', 'desc'));
for (const u of ['oown', 'oadm', 'oscorer', 'oviewer', 'sa']) allow(`org staff ${u} lists registrations`, () => getDocs(regs(as(u))));
allow('org team admin lists own team registrations', () => getDocs(regs(as('ocadm'), [where('clubId', '==', 'C1')])));
allow('player lists own registrations', () => getDocs(regs(as('plain'), [where('userId', '==', 'plain')])));
deny('plain user lists all registrations', () => getDocs(regs(as('req'))));
for (const u of ['oown', 'oadm', 'oscorer', 'oviewer', 'sa']) allow(`org staff ${u} reads audit log`, () => getDocs(query(collection(as(u), 'series_audit_logs'), where('seriesId', '==', 'S1'), orderBy('timestamp', 'desc'))));
deny('plain user reads org audit log', () => getDocs(query(collection(as('plain'), 'series_audit_logs'), where('seriesId', '==', 'S1'))));
allow('signed-in user reads org announcements', () => getDocs(query(collection(as('plain'), 'series/S1/announcements'), orderBy('createdAt', 'desc'), limit(50))));

// ── Notifications ───────────────────────────────────────────────────────────
allow('user lists own inbox', () => getDocs(query(collection(as('owner'), 'notifications'), where('userId', '==', 'owner'), orderBy('createdAt', 'desc'), limit(20))));
allow('user unread badge', () => getDocs(query(collection(as('owner'), 'notifications'), where('userId', '==', 'owner'), where('read', '==', false), limit(100))));
allow('user marks own notification read', () => updateDoc(doc(as('owner'), 'notifications/n_owner_T1'), { read: true, isRead: true }));
allow('actor finds own engagement notifications', () => getDocs(query(collection(as('req'), 'notifications'), where('addedByUserId', '==', 'req'), where('type', '==', 'team_join_request'), where('requestId', '==', 'x'), limit(50))));
deny('user reads someone else\'s inbox', () => getDocs(query(collection(as('plain'), 'notifications'), where('userId', '==', 'owner'))));

// ── Community ───────────────────────────────────────────────────────────────
test('allow: post author deletes their post with other people\'s likes and comments', async () => {
  const db = as('owner');
  for (const d of (await getDocs(query(collection(db, 'community_posts/P1/likes'), limit(200)))).docs) await assertSucceeds(deleteDoc(d.ref));
  for (const c of (await getDocs(query(collection(db, 'community_posts/P1/comments'), limit(200)))).docs) {
    for (const l of (await getDocs(query(collection(db, `community_posts/P1/comments/${c.id}/likes`), limit(200)))).docs) await assertSucceeds(deleteDoc(l.ref));
    await assertSucceeds(deleteDoc(c.ref));
  }
  await assertSucceeds(deleteDoc(doc(db, 'community_posts/P1')));
});
deny('post author cannot list who saved their post', () => getDocs(collection(as('owner'), 'community_posts/P1/saves')));
test('deny: non-author cannot clean up likes on someone else\'s post', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), 'community_posts/P2'), { authorId: 'owner', title: 't', createdAt: NOW });
    await setDoc(doc(c.firestore(), 'community_posts/P2/likes/plain'), { userId: 'plain' });
    await setDoc(doc(c.firestore(), 'community_posts/P2/comments/c1'), { authorId: 'plain', text: 'x' });
  });
  await assertFails(deleteDoc(doc(as('req'), 'community_posts/P2/likes/plain')));
  await assertFails(deleteDoc(doc(as('req'), 'community_posts/P2/comments/c1')));
});
allow('community moderator (super admin) removes a comment under any post', () => deleteDoc(doc(as('sa'), 'community_posts/P2/comments/c1')));
deny('user deletes someone else\'s like on someone else\'s post', () => deleteDoc(doc(as('req'), 'community_posts/P1/likes/plain')));

// ── Collection-group reads ──────────────────────────────────────────────────
allow('signed-in viewer lists replay markers for a match (collection group)', () => getDocs(query(collectionGroup(as('plain'), 'replayMarkers'), where('matchId', '==', 'M1'))));
allow('scorer dedupes a replay marker (collection group)', () => getDocs(query(collectionGroup(as('owner'), 'replayMarkers'), where('matchId', '==', 'M1'), where('streamSessionId', '==', 'SS1'), where('ballEventId', '==', 'b1'), where('kind', '==', 'six'), limit(1))));
allow('user lists own fantasy entries (collection group)', () => getDocs(query(collectionGroup(as('plain'), 'entries'), where('userId', '==', 'plain'), orderBy('updatedAt', 'desc'))));
allow('league creator refreshes everyone\'s points', () => {
  const db = as('owner'); const b = writeBatch(db);
  b.update(doc(db, 'fantasy_leagues/F1/entries/E1'), { totalPoints: 10, updatedAt: NOW });
  b.update(doc(db, 'fantasy_leagues/F1/entries/E2'), { totalPoints: 20, updatedAt: NOW });
  return b.commit();
});
deny('league creator cannot change someone else\'s squad', () => updateDoc(doc(as('owner'), 'fantasy_leagues/F1/entries/E1'), { playerIds: ['x'] }));
deny('player cannot change another player\'s points', () => updateDoc(doc(as('plain'), 'fantasy_leagues/F1/entries/E2'), { totalPoints: 999, updatedAt: NOW }));
allow('player refreshes own entry points', () => updateDoc(doc(as('plain'), 'fantasy_leagues/F1/entries/E1'), { totalPoints: 11, updatedAt: NOW }));
allow('guest reads a fantasy league leaderboard', () => getDocs(query(collection(anon(), 'fantasy_leagues/F1/entries'), orderBy('totalPoints', 'desc'))));

// ── Chats ───────────────────────────────────────────────────────────────────
allow('user lists own chats', () => getDocs(query(collection(as('plain'), 'chats'), where('participantIds', 'array-contains', 'plain'), orderBy('lastMessageAt', 'desc'))));
allow('user reads messages in own chat', () => getDocs(query(collection(as('req'), 'chats/plain_req/messages'), orderBy('createdAt'), limit(200))));
allow('user checks a chat that does not exist yet', () => getDoc(doc(as('plain'), 'chats/inv_plain')));
deny('outsider reads a chat', () => getDocs(query(collection(as('inv'), 'chats/plain_req/messages'))));
allow('user lists own blocks', () => getDocs(query(collection(as('plain'), 'chat_blocks'), where('blockerId', '==', 'plain'))));

// ── Misc signed-in reads ────────────────────────────────────────────────────
allow('signed-in user reads platform admin list (Discover badges)', () => getDoc(doc(as('plain'), 'app_meta/platform_admins')));
allow('team code allocation (app_meta counter)', () => setDoc(doc(as('plain'), 'app_meta/cf_team_ids'), { lastNumber: 3, updatedAt: NOW }, { merge: true }));
