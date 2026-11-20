import '../../../data/models/match_player_snapshot.dart';

/// Walk-ins in org matches. A walk-in is a player without a CrickFlow account:
/// a match-only guest, or a roster entry that is not a registered user.
/// Mirrors `functions/src/series/orgWalkIns.js` (the server is the authority).
bool isWalkInSnapshot(MatchPlayerSnapshot s) =>
    s.isMatchOnlyPlayer || !s.isRegisteredUser || s.id.startsWith('guest_');

List<MatchPlayerSnapshot> walkInsIn(Iterable<MatchPlayerSnapshot> players) =>
    [for (final p in players) if (isWalkInSnapshot(p)) p];

const kOrgNoWalkInsMessage =
    'This org does not allow walk-in players. Pick players who have a '
    'CrickFlow account.';
