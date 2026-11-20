/**
 * Callable: add an existing (normal or quick) match to a tournament.
 * Tournament owner/admins only. Validates teams + existing links, links the
 * match, registers it on the tournament and applies standings when the match
 * already has a result.
 */
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { updateTournamentStandings } = require('../utils/tournament');
const { LinkMatchError, validateLink, shouldApplyStandings } = require('./linkMatchOps');

async function memberRoleFor(db, tournamentId, uid) {
  const snap = await db
    .collection('tournament_members')
    .where('tournamentId', '==', tournamentId)
    .where('userId', '==', uid)
    .limit(1)
    .get();
  if (snap.empty) return null;
  return snap.docs[0].data().role || null;
}

exports.linkMatchToTournament = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required');

  const tournamentId = String(request.data?.tournamentId || '').trim();
  const matchId = String(request.data?.matchId || '').trim();
  const registerOnly = request.data?.mode === 'register';
  if (!tournamentId || !matchId) {
    throw new HttpsError('invalid-argument', 'tournamentId and matchId are required');
  }

  const db = getFirestore();
  const tRef = db.collection('tournaments').doc(tournamentId);
  const mRef = db.collection('matches').doc(matchId);
  const memberRole = await memberRoleFor(db, tournamentId, uid);

  let linkedMatch;
  try {
    linkedMatch = await db.runTransaction(async (tx) => {
      const [tSnap, mSnap] = await Promise.all([tx.get(tRef), tx.get(mRef)]);
      const tournament = tSnap.exists ? tSnap.data() : null;
      const match = mSnap.exists ? mSnap.data() : null;
      const patch = validateLink({
        tournamentId,
        tournament,
        match,
        uid,
        memberRole,
        registerOnly,
      });
      const alreadyListed = (tournament.matchIds || []).includes(matchId);
      const now = new Date().toISOString();
      if (registerOnly && alreadyListed) {
        return { ...match, id: matchId, skipStandings: true };
      }
      tx.update(mRef, {
        ...patch,
        linkedToTournamentAt: now,
        linkedToTournamentBy: uid,
        updatedAt: now,
      });
      tx.update(tRef, {
        matchIds: FieldValue.arrayUnion(matchId),
        updatedAt: now,
      });
      return { ...match, ...patch, id: matchId };
    });
  } catch (err) {
    if (err instanceof LinkMatchError) throw new HttpsError(err.code, err.message);
    throw err;
  }

  let standingsUpdated = false;
  // Matches created inside the tournament get standings from onMatchCompleted;
  // only matches linked after their result need a standings pass here.
  if (!registerOnly && !linkedMatch.skipStandings && shouldApplyStandings(linkedMatch)) {
    await updateTournamentStandings(db, tournamentId, linkedMatch);
    standingsUpdated = true;
  }

  return { ok: true, matchId, tournamentId, standingsUpdated };
});
