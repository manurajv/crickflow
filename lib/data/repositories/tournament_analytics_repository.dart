import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/models/ball_event_model.dart';
import '../../data/models/match_model.dart';
import '../../domain/services/tournament/tournament_analytics_engine.dart';
import '../../domain/services/tournament/tournament_analytics_models.dart';
import '../models/tournament/tournament_analytics_doc.dart';
import 'match_repository.dart';
import 'tournament_repository.dart';

class TournamentAnalyticsRepository {
  TournamentAnalyticsRepository({
    FirebaseFirestore? firestore,
    TournamentAnalyticsEngine? engine,
    MatchRepository? matchRepository,
    TournamentRepository? tournamentRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _engine = engine ?? TournamentAnalyticsEngine(),
        _matchRepository = matchRepository,
        _tournamentRepository = tournamentRepository;

  final FirebaseFirestore _firestore;
  final TournamentAnalyticsEngine _engine;
  final MatchRepository? _matchRepository;
  final TournamentRepository? _tournamentRepository;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('tournament_analytics');

  Stream<TournamentAnalyticsDoc?> watchDoc(String tournamentId) {
    return _collection.doc(tournamentId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return TournamentAnalyticsDoc.fromMap(tournamentId, snap.data()!);
    });
  }

  Future<TournamentAnalyticsDoc?> getDoc(String tournamentId) async {
    final snap = await _collection.doc(tournamentId).get();
    if (!snap.exists || snap.data() == null) return null;
    return TournamentAnalyticsDoc.fromMap(tournamentId, snap.data()!);
  }

  Future<TournamentAnalyticsSnapshot> computeSnapshot({
    required String tournamentId,
    required List<MatchModel> matches,
    required Map<String, List<BallEventModel>> eventsByMatch,
    TournamentAnalyticsFilter filter = const TournamentAnalyticsFilter(),
  }) {
    final tournamentMatches =
        matches.where((m) => m.tournamentId == tournamentId).toList();
    return Future.value(
      _engine.build(
        allMatches: tournamentMatches,
        eventsByMatch: eventsByMatch,
        filter: filter,
      ),
    );
  }

  Future<TournamentAnalyticsSnapshot> syncTournamentAnalytics(
    String tournamentId, {
    TournamentAnalyticsFilter filter = const TournamentAnalyticsFilter(),
  }) async {
    final matchRepo = _matchRepository;
    final tournamentRepo = _tournamentRepository;
    if (matchRepo == null || tournamentRepo == null) {
      return const TournamentAnalyticsSnapshot();
    }

    final tournament = await tournamentRepo.getTournament(tournamentId);
    if (tournament == null) return const TournamentAnalyticsSnapshot();

    final matches = <MatchModel>[];
    for (final id in tournament.matchIds) {
      final m = await matchRepo.getMatch(id);
      if (m != null) matches.add(m);
    }

    final eventsByMatch = <String, List<BallEventModel>>{};
    for (final m in matches) {
      try {
        final events = await matchRepo.getBallEvents(m.id);
        if (events.isNotEmpty) eventsByMatch[m.id] = events;
      } catch (_) {}
    }

    final snapshot = _engine.build(
      allMatches: matches,
      eventsByMatch: eventsByMatch,
      filter: filter,
    );

    final doc = TournamentAnalyticsDoc.fromSnapshot(tournamentId, snapshot);
    await _collection.doc(tournamentId).set(doc.toMap(), SetOptions(merge: true));

    return snapshot;
  }
}
