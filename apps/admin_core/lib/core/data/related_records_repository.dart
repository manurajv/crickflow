import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/admin_collections.dart';
import '../constants/admin_query_limits.dart';
import '../../features/grounds/models/managed_ground.dart';
import '../../features/matches/models/managed_match.dart';
import '../../features/teams/models/managed_team.dart';
import '../../features/tournaments/models/managed_tournament.dart';
import '../../features/users/models/managed_user.dart';
import 'related_records.dart';

/// Live related-entity lookups for Super Admin detail panels.
///
/// Each section fails independently. Missing collections, indexes, or
/// permissions become an error string — never invented rows.
class RelatedRecordsRepository {
  RelatedRecordsRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  int get _limit => AdminQueryLimits.relatedRecordsMax;

  Future<UserRelatedSnapshot> fetchForUser(ManagedUser user) async {
    final uid = user.id;
    final teamId = user.currentTeamId;

    final membership = await _section(() async {
      final records = <String, RelatedRecord>{};
      if (teamId != null && teamId.isNotEmpty) {
        final doc = await _db
            .collection(AdminCollections.teams)
            .doc(teamId)
            .get();
        if (doc.exists) {
          records[doc.id] = _teamRecord(doc.id, doc.data() ?? const {});
        }
      }
      for (final snap in await Future.wait([
        _get(_teams.where('playerIds', arrayContains: uid)),
        _get(_teams.where('createdBy', isEqualTo: uid)),
      ])) {
        for (final d in snap) {
          records[d.id] = _teamRecord(d.id, d.data());
        }
      }
      return records.values.toList();
    });

    final teamIds = {
      if (teamId != null && teamId.isNotEmpty) teamId,
      for (final t in membership.items) t.id,
    };

    final matches = await _section(() async {
      final records = <String, RelatedRecord>{};
      final queries =
          <Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>>[
            _get(_matches.where('createdBy', isEqualTo: uid)),
            _get(_matches.where('scorerIds', arrayContains: uid)),
          ];
      for (final id in teamIds.take(5)) {
        queries.add(_get(_matches.where('teamAId', isEqualTo: id)));
        queries.add(_get(_matches.where('teamBId', isEqualTo: id)));
      }
      for (final snap in await Future.wait(queries)) {
        for (final d in snap) {
          records[d.id] = _matchRecord(d.id, d.data());
        }
      }
      return _newest(records.values);
    });

    final tournaments = await _section(() async {
      final records = <String, RelatedRecord>{};
      final queries =
          <Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>>[
            _get(_tournaments.where('createdBy', isEqualTo: uid)),
            _get(_tournaments.where('organizerId', isEqualTo: uid)),
          ];
      for (final id in teamIds.take(5)) {
        queries.add(_get(_tournaments.where('teamIds', arrayContains: id)));
      }
      for (final snap in await Future.wait(queries)) {
        for (final d in snap) {
          records[d.id] = _tournamentRecord(d.id, d.data());
        }
      }
      return _newest(records.values);
    });

    final reports = await _section(() async {
      final records = <String, RelatedRecord>{};
      for (final snap in await Future.wait([
        _get(_communityReports.where('reporterUserId', isEqualTo: uid)),
        _get(_opportunityReports.where('reporterUserId', isEqualTo: uid)),
        _get(_communityReports.where('authorId', isEqualTo: uid)),
        _get(_opportunityReports.where('authorId', isEqualTo: uid)),
      ])) {
        for (final d in snap) {
          records[d.id] = _reportRecord(d.id, d.data());
        }
      }
      return _newest(records.values);
    });

    final community = await _section(() async {
      return [
        for (final d in await _get(
          _community.where('authorId', isEqualTo: uid),
        ))
          _postRecord(d.id, d.data()),
      ];
    });

    final opportunity = await _section(() async {
      return [
        for (final d in await _get(
          _opportunities.where('authorId', isEqualTo: uid),
        ))
          _postRecord(d.id, d.data()),
      ];
    });

    final notifications = await _section(() async {
      return [
        for (final d in await _get(
          _db
              .collection(AdminCollections.notifications)
              .where('userId', isEqualTo: uid),
        ))
          _notificationRecord(d.id, d.data()),
      ];
    });

    return UserRelatedSnapshot(
      teams: membership,
      matches: matches,
      tournaments: tournaments,
      reports: reports,
      communityPosts: community,
      opportunityPosts: opportunity,
      notifications: notifications,
      lastLoginAt: user.lastLoginAt,
    );
  }

  Future<TeamRelatedSnapshot> fetchForTeam(ManagedTeam team) async {
    final id = team.id;
    final squad = await _section(() => _fetchPlayers(team.playerIds));
    final matches = await _section(() async {
      final records = <String, RelatedRecord>{};
      for (final snap in await Future.wait([
        _get(_matches.where('teamAId', isEqualTo: id)),
        _get(_matches.where('teamBId', isEqualTo: id)),
      ])) {
        for (final d in snap) {
          records[d.id] = _matchRecord(d.id, d.data());
        }
      }
      return _newest(records.values);
    });
    final tournaments = await _section(() async {
      return [
        for (final d in await _get(
          _tournaments.where('teamIds', arrayContains: id),
        ))
          _tournamentRecord(d.id, d.data()),
      ];
    });
    final reports = await _section(() async {
      final records = <String, RelatedRecord>{};
      for (final snap in await Future.wait([
        _get(_communityReports.where('teamId', isEqualTo: id)),
        _get(_opportunityReports.where('teamId', isEqualTo: id)),
      ])) {
        for (final d in snap) {
          records[d.id] = _reportRecord(d.id, d.data());
        }
      }
      return _newest(records.values);
    });
    return TeamRelatedSnapshot(
      squad: squad,
      matches: matches,
      tournaments: tournaments,
      reports: reports,
      followersCount: team.followersCount,
    );
  }

  Future<MatchRelatedSnapshot> fetchForMatch(ManagedMatch match) async {
    final setup = match.setupSummary;
    final officialItems = <RelatedRecord>[
      for (final name in setup.umpires)
        RelatedRecord(id: 'umpire-$name', title: name, subtitle: 'Umpire'),
      for (final name in setup.scorers)
        RelatedRecord(id: 'scorer-$name', title: name, subtitle: 'Scorer'),
      if (match.currentScorerName.isNotEmpty &&
          !setup.scorers.contains(match.currentScorerName))
        RelatedRecord(
          id: 'current-scorer',
          title: match.currentScorerName,
          subtitle: 'Current scorer',
        ),
      for (final name in setup.commentators)
        RelatedRecord(id: 'comm-$name', title: name, subtitle: 'Commentator'),
      for (final name in setup.streamers)
        RelatedRecord(id: 'stream-$name', title: name, subtitle: 'Streamer'),
      if (setup.referee.isNotEmpty)
        RelatedRecord(id: 'referee', title: setup.referee, subtitle: 'Referee'),
    ];

    final scoreItems = <RelatedRecord>[
      if (match.resultSummary.isNotEmpty)
        RelatedRecord(
          id: 'result',
          title: match.resultSummary,
          subtitle: 'Result',
        ),
      if (match.tossWinner != null)
        RelatedRecord(
          id: 'toss',
          title: match.tossWinner!,
          subtitle: match.tossDecision ?? 'Toss',
        ),
      for (var i = 0; i < setup.inningsLines.length; i++)
        RelatedRecord(
          id: 'inn-$i',
          title: setup.inningsLines[i],
          subtitle: 'Scorecard',
        ),
      if (setup.inningsLines.isEmpty &&
          (match.live.runs > 0 ||
              match.live.wickets > 0 ||
              match.live.legalBalls > 0))
        RelatedRecord(
          id: 'live',
          title: '${match.scoreLine} (${match.currentInningsLabel})',
          subtitle: [
            if (match.live.strikerName != null)
              'Striker ${match.live.strikerName}',
            if (match.live.currentBowlerName != null)
              'Bowler ${match.live.currentBowlerName}',
          ].join(' · '),
        ),
    ];

    final streamItems = <RelatedRecord>[
      RelatedRecord(
        id: 'stream-status',
        title: match.streamingStatus.label,
        subtitle: match.streamingPlatform.label,
      ),
      if (match.watchUrl != null && match.watchUrl!.isNotEmpty)
        RelatedRecord(
          id: 'watch',
          title: match.watchUrl!,
          subtitle: 'Watch URL',
        ),
      if (match.viewerCount > 0)
        RelatedRecord(
          id: 'viewers',
          title: '${match.viewerCount} viewers',
          subtitle: 'Last recorded on the match document',
        ),
    ];

    final reports = await _section(() async {
      final records = <String, RelatedRecord>{};
      for (final snap in await Future.wait([
        _get(_communityReports.where('matchId', isEqualTo: match.id)),
        _get(_opportunityReports.where('matchId', isEqualTo: match.id)),
      ])) {
        for (final d in snap) {
          records[d.id] = _reportRecord(d.id, d.data());
        }
      }
      return _newest(records.values);
    });

    return MatchRelatedSnapshot(
      teamAXi: setup.teamAXi,
      teamBXi: setup.teamBXi,
      teamAName: match.teamAName,
      teamBName: match.teamBName,
      officials: RelatedSection(items: officialItems),
      scorecard: RelatedSection(items: scoreItems),
      stream: RelatedSection(items: streamItems),
      reports: reports,
    );
  }

  Future<TournamentRelatedSnapshot> fetchForTournament(
    ManagedTournament tournament,
  ) async {
    final teams = await _section(() => _fetchTeams(tournament.teamIds));
    final fixtures = await _section(() async {
      final records = <String, RelatedRecord>{};
      for (final d in await _get(
        _matches.where('tournamentId', isEqualTo: tournament.id),
      )) {
        records[d.id] = _matchRecord(d.id, d.data());
      }
      if (records.isEmpty && tournament.matchIds.isNotEmpty) {
        for (final d in await _getByIds(
          AdminCollections.matches,
          tournament.matchIds,
        )) {
          records[d.id] = _matchRecord(d.id, d.data() ?? const {});
        }
      }
      return _newest(records.values);
    });
    final reports = await _section(() async {
      final records = <String, RelatedRecord>{};
      for (final snap in await Future.wait([
        _get(_communityReports.where('tournamentId', isEqualTo: tournament.id)),
        _get(
          _opportunityReports.where('tournamentId', isEqualTo: tournament.id),
        ),
        _get(_community.where('tournamentId', isEqualTo: tournament.id)),
      ])) {
        for (final d in snap) {
          final data = d.data();
          records[d.id] =
              data.containsKey('reason') || data.containsKey('reporterUserId')
              ? _reportRecord(d.id, data)
              : _postRecord(d.id, data);
        }
      }
      return _newest(records.values);
    });
    return TournamentRelatedSnapshot(
      teams: teams,
      fixtures: fixtures,
      reports: reports,
      organizer: tournament.organizerName,
    );
  }

  Future<GroundRelatedSnapshot> fetchForGround(ManagedGround ground) async {
    final name = ground.name.trim();
    final matches = await _section(() async {
      final records = <String, RelatedRecord>{};
      final queries =
          <Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>>[
            _get(_matches.where('venue', isEqualTo: name)),
            if (ground.id.isNotEmpty)
              _get(_matches.where('groundId', isEqualTo: ground.id)),
          ];
      for (final snap in await Future.wait(queries)) {
        for (final d in snap) {
          records[d.id] = _matchRecord(d.id, d.data());
        }
      }
      return _newest(records.values);
    });
    final tournaments = await _section(() async {
      final records = <String, RelatedRecord>{};
      if (name.isNotEmpty) {
        for (final d in await _get(
          _tournaments.where('grounds', arrayContains: name),
        )) {
          records[d.id] = _tournamentRecord(d.id, d.data());
        }
      }
      if (ground.tournamentIds.isNotEmpty) {
        for (final d in await _getByIds(
          AdminCollections.tournaments,
          ground.tournamentIds,
        )) {
          records[d.id] = _tournamentRecord(d.id, d.data() ?? const {});
        }
      }
      return _newest(records.values);
    });
    final photos = <String>[
      if (ground.photoUrl != null && ground.photoUrl!.trim().isNotEmpty)
        ground.photoUrl!,
      ...ground.galleryUrls.where((u) => u.trim().isNotEmpty),
    ];
    return GroundRelatedSnapshot(
      matches: matches,
      tournaments: tournaments,
      photoUrls: photos.toSet().toList(),
      matchesHosted: ground.matchesHosted,
    );
  }

  CollectionReference<Map<String, dynamic>> get _teams =>
      _db.collection(AdminCollections.teams);
  CollectionReference<Map<String, dynamic>> get _matches =>
      _db.collection(AdminCollections.matches);
  CollectionReference<Map<String, dynamic>> get _tournaments =>
      _db.collection(AdminCollections.tournaments);
  CollectionReference<Map<String, dynamic>> get _community =>
      _db.collection(AdminCollections.communityPosts);
  CollectionReference<Map<String, dynamic>> get _opportunities =>
      _db.collection(AdminCollections.opportunityPosts);
  CollectionReference<Map<String, dynamic>> get _communityReports =>
      _db.collection(AdminCollections.communityPostReports);
  CollectionReference<Map<String, dynamic>> get _opportunityReports =>
      _db.collection(AdminCollections.opportunityPostReports);

  Future<RelatedSection> _section(
    Future<List<RelatedRecord>> Function() load,
  ) async {
    try {
      final items = await load();
      return RelatedSection(items: _newest(items));
    } catch (e) {
      return RelatedSection(error: e.toString());
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _get(
    Query<Map<String, dynamic>> query,
  ) async {
    final snap = await query.limit(_limit).get();
    return snap.docs;
  }

  Future<List<DocumentSnapshot<Map<String, dynamic>>>> _getByIds(
    String collection,
    List<String> ids,
  ) async {
    final unique = ids
        .where((id) => id.isNotEmpty)
        .toSet()
        .take(_limit)
        .toList();
    final docs = <DocumentSnapshot<Map<String, dynamic>>>[];
    for (var i = 0; i < unique.length; i += 10) {
      final chunk = unique.sublist(
        i,
        i + 10 > unique.length ? unique.length : i + 10,
      );
      final snap = await _db
          .collection(collection)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      docs.addAll(snap.docs);
    }
    return docs;
  }

  Future<List<RelatedRecord>> _fetchPlayers(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final docs = await _getByIds(AdminCollections.players, ids);
    return [
      for (final d in docs)
        if (d.exists) _playerRecord(d.id, d.data() ?? const {}),
    ];
  }

  Future<List<RelatedRecord>> _fetchTeams(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final docs = await _getByIds(AdminCollections.teams, ids);
    return [
      for (final d in docs)
        if (d.exists) _teamRecord(d.id, d.data() ?? const {}),
    ];
  }

  List<RelatedRecord> _newest(Iterable<RelatedRecord> items) {
    final list = items.toList()
      ..sort((a, b) {
        final at = a.occurredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.occurredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });
    if (list.length <= _limit) return list;
    return list.sublist(0, _limit);
  }

  RelatedRecord _teamRecord(String id, Map<String, dynamic> map) {
    final city = (map['location'] is Map)
        ? (Map<String, dynamic>.from(map['location'] as Map)['city']
                  as String? ??
              '')
        : (map['city'] as String? ?? '');
    return RelatedRecord(
      id: id,
      title: (map['name'] as String?)?.trim().isNotEmpty == true
          ? (map['name'] as String).trim()
          : 'Team',
      subtitle: city,
      occurredAt: _date(map['createdAt'] ?? map['updatedAt']),
    );
  }

  RelatedRecord _matchRecord(String id, Map<String, dynamic> map) {
    final a = (map['teamAName'] as String?)?.trim() ?? '';
    final b = (map['teamBName'] as String?)?.trim() ?? '';
    final title = (map['title'] as String?)?.trim();
    return RelatedRecord(
      id: id,
      title: (title != null && title.isNotEmpty)
          ? title
          : '${a.isEmpty ? 'Team A' : a} vs ${b.isEmpty ? 'Team B' : b}',
      subtitle: (map['status'] as String?) ?? (map['venue'] as String? ?? ''),
      occurredAt: _date(
        map['scheduledAt'] ?? map['createdAt'] ?? map['updatedAt'],
      ),
    );
  }

  RelatedRecord _tournamentRecord(String id, Map<String, dynamic> map) {
    return RelatedRecord(
      id: id,
      title: (map['name'] as String?)?.trim().isNotEmpty == true
          ? (map['name'] as String).trim()
          : 'Tournament',
      subtitle: (map['status'] as String?) ?? '',
      occurredAt: _date(map['startDate'] ?? map['createdAt']),
    );
  }

  RelatedRecord _playerRecord(String id, Map<String, dynamic> map) {
    final name = (map['fullName'] as String?)?.trim().isNotEmpty == true
        ? (map['fullName'] as String).trim()
        : ((map['name'] as String?)?.trim() ?? 'Player');
    final role = (map['role'] as String?) ?? '';
    return RelatedRecord(id: id, title: name, subtitle: role);
  }

  RelatedRecord _postRecord(String id, Map<String, dynamic> map) {
    final title = (map['title'] as String?)?.trim();
    final body =
        (map['body'] as String?)?.trim() ??
        (map['text'] as String?)?.trim() ??
        (map['caption'] as String?)?.trim() ??
        '';
    return RelatedRecord(
      id: id,
      title: (title != null && title.isNotEmpty)
          ? title
          : (body.isNotEmpty ? body : 'Post'),
      subtitle: body.isNotEmpty && title != null && title.isNotEmpty
          ? body
          : '',
      occurredAt: _date(map['createdAt'] ?? map['updatedAt']),
    );
  }

  RelatedRecord _reportRecord(String id, Map<String, dynamic> map) {
    return RelatedRecord(
      id: id,
      title: (map['reason'] as String?)?.trim().isNotEmpty == true
          ? (map['reason'] as String).trim()
          : 'Report',
      subtitle: (map['status'] as String?) ?? '',
      occurredAt: _date(map['createdAt']),
    );
  }

  RelatedRecord _notificationRecord(String id, Map<String, dynamic> map) {
    return RelatedRecord(
      id: id,
      title: (map['title'] as String?)?.trim().isNotEmpty == true
          ? (map['title'] as String).trim()
          : 'Notification',
      subtitle: (map['type'] as String?) ?? (map['body'] as String? ?? ''),
      occurredAt: _date(map['createdAt']),
    );
  }

  DateTime? _date(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        raw > 9999999999 ? raw : raw * 1000,
      );
    }
    return null;
  }
}
