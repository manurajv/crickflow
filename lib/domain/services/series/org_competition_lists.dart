import '../../../core/constants/enums.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/tournament_model.dart';
import '../../scoring/match_lifecycle.dart';

/// Status chips on the org Matches / Tournaments tabs.
enum OrgStatusFilter {
  all,
  live,
  upcoming,
  completed;

  String get label => switch (this) {
        OrgStatusFilter.all => 'All',
        OrgStatusFilter.live => 'Live',
        OrgStatusFilter.upcoming => 'Upcoming',
        OrgStatusFilter.completed => 'Completed',
      };
}

/// Where a list item sits: live now, still to play, or finished.
enum OrgBucket { live, upcoming, completed }

/// Matches filtered by tournament: every match, only standalone matches, or the
/// matches of one org tournament (its id).
const String kOrgStandaloneFilter = '__standalone__';

OrgBucket orgMatchBucket(MatchModel match) {
  final status = MatchLifecycle.effectiveStatus(match);
  if (status == MatchStatus.completed || status == MatchStatus.abandoned) {
    return OrgBucket.completed;
  }
  if (MatchLifecycle.isEffectivelyLive(match)) return OrgBucket.live;
  return OrgBucket.upcoming;
}

OrgBucket orgTournamentBucket(TournamentModel t) => switch (t.status) {
      TournamentStatus.live => OrgBucket.live,
      TournamentStatus.upcoming || TournamentStatus.draft => OrgBucket.upcoming,
      TournamentStatus.completed ||
      TournamentStatus.cancelled =>
        OrgBucket.completed,
    };

/// Who sees an org item: approved ones are public; pending requests only to
/// org admins and to whoever asked for them. Rejected / draft never show.
bool orgItemVisible({
  required String? officialStatus,
  required String? createdBy,
  required bool isAdmin,
  String? uid,
}) {
  if (officialStatus == 'approved') return true;
  if (officialStatus == 'pendingApproval') {
    return isAdmin || (uid != null && uid.isNotEmpty && createdBy == uid);
  }
  return false;
}

/// Org matches for the Matches tab: no quick matches (not allowed in orgs).
List<MatchModel> visibleOrgMatches(
  Iterable<MatchModel> matches, {
  required bool isAdmin,
  String? uid,
}) =>
    matches
        .where((m) =>
            !m.isQuickMatch &&
            orgItemVisible(
              officialStatus: m.seriesOfficialStatus,
              createdBy: m.createdBy,
              isAdmin: isAdmin,
              uid: uid,
            ))
        .toList();

List<TournamentModel> visibleOrgTournaments(
  Iterable<TournamentModel> tournaments, {
  required bool isAdmin,
  String? uid,
}) =>
    tournaments
        .where((t) =>
            orgItemVisible(
              officialStatus: t.seriesOfficialStatus,
              createdBy: t.createdBy ?? t.organizerId,
              isAdmin: isAdmin,
              uid: uid,
            ))
        .toList();

bool matchPassesTournamentFilter(MatchModel m, String? filter) {
  if (filter == null || filter.isEmpty) return true;
  final tid = m.tournamentId ?? '';
  if (filter == kOrgStandaloneFilter) return tid.isEmpty;
  return tid == filter;
}

DateTime _matchWhen(MatchModel m) =>
    m.scheduledAt ??
    m.startedAt ??
    m.completedAt ??
    m.createdAt ??
    DateTime.fromMillisecondsSinceEpoch(0);

DateTime _matchDone(MatchModel m) =>
    m.completedAt ??
    m.startedAt ??
    m.scheduledAt ??
    m.createdAt ??
    DateTime.fromMillisecondsSinceEpoch(0);

/// One group on a list tab.
class OrgSection<T> {
  const OrgSection(this.bucket, this.items);
  final OrgBucket bucket;
  final List<T> items;

  String get title => switch (bucket) {
        OrgBucket.live => 'Live now',
        OrgBucket.upcoming => 'Upcoming',
        OrgBucket.completed => 'Completed',
      };
}

/// Live → Upcoming → Completed. Live: most recent first. Upcoming: soonest
/// first. Completed: latest result first. Empty sections are dropped.
List<OrgSection<MatchModel>> groupOrgMatches(
  Iterable<MatchModel> matches, {
  OrgStatusFilter status = OrgStatusFilter.all,
  String? tournamentFilter,
  String query = '',
}) {
  final q = query.trim().toLowerCase();
  final live = <MatchModel>[];
  final upcoming = <MatchModel>[];
  final done = <MatchModel>[];
  for (final m in matches) {
    if (!matchPassesTournamentFilter(m, tournamentFilter)) continue;
    if (q.isNotEmpty &&
        !('${m.teamAName} ${m.teamBName} ${m.title}'.toLowerCase().contains(q))) {
      continue;
    }
    switch (orgMatchBucket(m)) {
      case OrgBucket.live:
        live.add(m);
      case OrgBucket.upcoming:
        upcoming.add(m);
      case OrgBucket.completed:
        done.add(m);
    }
  }
  live.sort((a, b) => _matchDone(b).compareTo(_matchDone(a)));
  upcoming.sort((a, b) => _matchWhen(a).compareTo(_matchWhen(b)));
  done.sort((a, b) => _matchDone(b).compareTo(_matchDone(a)));
  bool want(OrgBucket b) =>
      status == OrgStatusFilter.all ||
      (status == OrgStatusFilter.live && b == OrgBucket.live) ||
      (status == OrgStatusFilter.upcoming && b == OrgBucket.upcoming) ||
      (status == OrgStatusFilter.completed && b == OrgBucket.completed);
  return [
    if (want(OrgBucket.live) && live.isNotEmpty)
      OrgSection(OrgBucket.live, live),
    if (want(OrgBucket.upcoming) && upcoming.isNotEmpty)
      OrgSection(OrgBucket.upcoming, upcoming),
    if (want(OrgBucket.completed) && done.isNotEmpty)
      OrgSection(OrgBucket.completed, done),
  ];
}

DateTime _tournamentStart(TournamentModel t) =>
    t.startDate ?? t.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

DateTime _tournamentEnd(TournamentModel t) =>
    t.endDate ??
    t.startDate ??
    t.createdAt ??
    DateTime.fromMillisecondsSinceEpoch(0);

List<OrgSection<TournamentModel>> groupOrgTournaments(
  Iterable<TournamentModel> tournaments, {
  OrgStatusFilter status = OrgStatusFilter.all,
  String query = '',
}) {
  final q = query.trim().toLowerCase();
  final live = <TournamentModel>[];
  final upcoming = <TournamentModel>[];
  final done = <TournamentModel>[];
  for (final t in tournaments) {
    if (q.isNotEmpty && !t.name.toLowerCase().contains(q)) continue;
    switch (orgTournamentBucket(t)) {
      case OrgBucket.live:
        live.add(t);
      case OrgBucket.upcoming:
        upcoming.add(t);
      case OrgBucket.completed:
        done.add(t);
    }
  }
  live.sort((a, b) => _tournamentStart(b).compareTo(_tournamentStart(a)));
  upcoming.sort((a, b) => _tournamentStart(a).compareTo(_tournamentStart(b)));
  done.sort((a, b) => _tournamentEnd(b).compareTo(_tournamentEnd(a)));
  bool want(OrgBucket b) =>
      status == OrgStatusFilter.all ||
      (status == OrgStatusFilter.live && b == OrgBucket.live) ||
      (status == OrgStatusFilter.upcoming && b == OrgBucket.upcoming) ||
      (status == OrgStatusFilter.completed && b == OrgBucket.completed);
  return [
    if (want(OrgBucket.live) && live.isNotEmpty)
      OrgSection(OrgBucket.live, live),
    if (want(OrgBucket.upcoming) && upcoming.isNotEmpty)
      OrgSection(OrgBucket.upcoming, upcoming),
    if (want(OrgBucket.completed) && done.isNotEmpty)
      OrgSection(OrgBucket.completed, done),
  ];
}

/// Status chip counts for a list (after visibility filtering).
Map<OrgStatusFilter, int> orgBucketCounts<T>(
  Iterable<T> items,
  OrgBucket Function(T) bucketOf,
) {
  var live = 0, upcoming = 0, done = 0;
  for (final i in items) {
    switch (bucketOf(i)) {
      case OrgBucket.live:
        live++;
      case OrgBucket.upcoming:
        upcoming++;
      case OrgBucket.completed:
        done++;
    }
  }
  return {
    OrgStatusFilter.all: live + upcoming + done,
    OrgStatusFilter.live: live,
    OrgStatusFilter.upcoming: upcoming,
    OrgStatusFilter.completed: done,
  };
}
