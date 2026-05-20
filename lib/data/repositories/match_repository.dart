import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/enums.dart';
import '../../data/models/ball_event_model.dart';
import '../../data/models/innings_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/overlay_state_model.dart';
import '../../core/utils/highlight_utils.dart';
import '../../domain/services/badge_service.dart';
import '../../domain/services/commentary_service.dart';
import '../../domain/services/scoring_engine.dart';
import '../services/public_scorecard_sync.dart';

class MatchRepository {
  MatchRepository({
    FirebaseFirestore? firestore,
    ScoringEngine? scoringEngine,
    BadgeService? badgeService,
    PublicScorecardSync? publicScorecardSync,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _scoringEngine = scoringEngine ?? ScoringEngine(),
        _badgeService = badgeService ?? BadgeService(),
        _publicSync = publicScorecardSync ?? PublicScorecardSync(),
        _uuid = const Uuid();

  final FirebaseFirestore _firestore;
  final ScoringEngine _scoringEngine;
  final BadgeService _badgeService;
  final PublicScorecardSync _publicSync;
  final Uuid _uuid;

  CollectionReference<Map<String, dynamic>> get _matches =>
      _firestore.collection(AppConstants.matchesCollection);

  DocumentReference<Map<String, dynamic>> _matchDoc(String id) =>
      _matches.doc(id);

  CollectionReference<Map<String, dynamic>> _ballEvents(String matchId) =>
      _matchDoc(matchId).collection('ball_events');

  Future<String> createMatch(MatchModel match) async {
    final id = match.id.isEmpty ? _uuid.v4() : match.id;
    await _matches.doc(id).set(match.toMap());
    return id;
  }

  Future<void> updateMatch(MatchModel match) async {
    await _matches.doc(match.id).update(match.toMap());
    await _syncPublicScorecard(match);
  }

  Future<void> _syncPublicScorecard(
    MatchModel match, {
    OverlayStateModel? overlay,
  }) async {
    try {
      await _publicSync.syncFromMatch(match, overlay: overlay);
    } catch (_) {
      // Non-fatal; Cloud Function may also sync.
    }
  }

  /// Partial update so live scoring writes are not overwritten during RTMP.
  Future<void> touchStreamHeartbeat(String matchId) async {
    await _matches.doc(matchId).update({
      'stream.lastHeartbeatAt': DateTime.now().toIso8601String(),
    });
  }

  Future<MatchModel?> getMatch(String id) async {
    final doc = await _matches.doc(id).get();
    if (!doc.exists) return null;
    return MatchModel.fromMap(doc.id, doc.data()!);
  }

  Stream<MatchModel?> watchMatch(String id) {
    return _matches.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return MatchModel.fromMap(doc.id, doc.data()!);
    });
  }

  Stream<List<MatchModel>> watchMatches({String? createdBy}) {
    Query<Map<String, dynamic>> query =
        _matches.orderBy('createdAt', descending: true);
    if (createdBy != null) {
      query = query.where('createdBy', isEqualTo: createdBy);
    }
    return query.limit(50).snapshots().map((snap) {
      return snap.docs
          .map((d) => MatchModel.fromMap(d.id, d.data()))
          .toList();
    });
  }

  /// All recent matches; live matches sorted to the top.
  Stream<List<MatchModel>> watchMatchFeed() {
    return _matches
        .orderBy('updatedAt', descending: true)
        .limit(40)
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map((d) => MatchModel.fromMap(d.id, d.data())).toList();
      list.sort((a, b) {
        final aLive = a.status == MatchStatus.live ? 0 : 1;
        final bLive = b.status == MatchStatus.live ? 0 : 1;
        if (aLive != bLive) return aLive.compareTo(bLive);
        return 0;
      });
      return list;
    });
  }

  Future<List<BallEventModel>> fetchBallEvents(String matchId) async {
    final snap = await _ballEvents(matchId).orderBy('sequence').get();
    return snap.docs
        .map((d) => BallEventModel.fromMap(d.id, d.data()))
        .toList();
  }

  Future<int> lastBallSequence(String matchId) async {
    final events = await fetchBallEvents(matchId);
    if (events.isEmpty) return 0;
    return events.last.sequence;
  }

  Future<ScoringInput> recordBall({
    required MatchModel match,
    required BallEventInput input,
    required int sequence,
  }) async {
    final result = _scoringEngine.recordBall(
      match: match,
      input: input,
      sequence: sequence,
    );

    final eventId = _uuid.v4();
    final highlight = HighlightUtils.classify(result.event);
    final commentary = result.event.commentary.trim().isEmpty
        ? CommentaryService.forEvent(result.event)
        : result.event.commentary;

    final event = BallEventModel(
      id: eventId,
      matchId: match.id,
      inningsNumber: result.event.inningsNumber,
      overNumber: result.event.overNumber,
      ballInOver: result.event.ballInOver,
      eventType: result.event.eventType,
      runs: result.event.runs,
      batsmanRuns: result.event.batsmanRuns,
      extraRuns: result.event.extraRuns,
      isLegalDelivery: result.event.isLegalDelivery,
      isFreeHit: result.event.isFreeHit,
      strikerId: result.event.strikerId,
      nonStrikerId: result.event.nonStrikerId,
      bowlerId: result.event.bowlerId,
      wicketType: result.event.wicketType,
      dismissedPlayerId: result.event.dismissedPlayerId,
      fielderId: result.event.fielderId,
      commentary: commentary,
      sequence: sequence,
      isHighlight: highlight.isHighlight,
      highlightTag: highlight.tag,
      noBallRunsMode: result.event.noBallRunsMode,
    );

    await _commitMatchState(
      matchId: match.id,
      matchData: result.match.toMap(),
      event: event,
      overlay: result.overlay,
    );

    return ScoringInput(match: result.match, event: event, overlay: result.overlay);
  }

  /// Deletes last ball event and replays remaining events from base innings.
  Future<MatchModel?> undoLastBall(String matchId) async {
    final match = await getMatch(matchId);
    if (match == null || match.currentInnings == null) return null;

    final events = await fetchBallEvents(matchId);
    if (events.isEmpty) return match;

    final last = events.removeLast();
    final base = _scoringEngine.baseInningsFrom(
      match.currentInnings!,
      events: events,
    );
    final replayed = _scoringEngine.replayInnings(
      match: match,
      baseInnings: base,
      events: events,
    );
    final overlay = _scoringEngine.buildOverlayForMatch(replayed);

    final batch = _firestore.batch();
    batch.delete(_ballEvents(matchId).doc(last.id));
    batch.update(_matchDoc(matchId), replayed.toMap());
    batch.set(
      _matchDoc(matchId).collection('overlay').doc('current'),
      overlay.toMap(),
    );
    await batch.commit();
    await _syncPublicScorecard(replayed, overlay: overlay);

    return replayed;
  }

  Future<void> updateLineup({
    required String matchId,
    required String strikerId,
    required String strikerName,
    required String nonStrikerId,
    required String nonStrikerName,
    required String bowlerId,
    required String bowlerName,
  }) async {
    final match = await getMatch(matchId);
    if (match == null || match.currentInnings == null) return;

    final inn = match.currentInnings!;
    final batsmen = List<BatsmanInningsModel>.from(inn.batsmen);
    final bowlers = List<BowlerInningsModel>.from(inn.bowlers);

    void upsertBatsman(String id, String name) {
      final idx = batsmen.indexWhere((b) => b.playerId == id);
      if (idx >= 0 && batsmen[idx].isOut) {
        throw StateError('Player is out and cannot bat again this innings');
      }
      if (idx >= 0) {
        final b = batsmen[idx];
        batsmen[idx] = BatsmanInningsModel(
          playerId: id,
          playerName: name,
          runs: b.runs,
          balls: b.balls,
          fours: b.fours,
          sixes: b.sixes,
          isOut: b.isOut,
          dismissalInfo: b.dismissalInfo,
        );
      } else {
        batsmen.add(BatsmanInningsModel(playerId: id, playerName: name));
      }
    }

    void upsertBowler(String id, String name) {
      final idx = bowlers.indexWhere((b) => b.playerId == id);
      if (idx >= 0) {
        final b = bowlers[idx];
        bowlers[idx] = BowlerInningsModel(
          playerId: id,
          playerName: name,
          oversBowledBalls: b.oversBowledBalls,
          runsConceded: b.runsConceded,
          wickets: b.wickets,
          wides: b.wides,
          noBalls: b.noBalls,
        );
      } else {
        bowlers.add(BowlerInningsModel(playerId: id, playerName: name));
      }
    }

    upsertBatsman(strikerId, strikerName);
    upsertBatsman(nonStrikerId, nonStrikerName);
    upsertBowler(bowlerId, bowlerName);

    final updatedInnings = InningsModel(
      inningsNumber: inn.inningsNumber,
      battingTeamId: inn.battingTeamId,
      bowlingTeamId: inn.bowlingTeamId,
      status: inn.status,
      totalRuns: inn.totalRuns,
      totalWickets: inn.totalWickets,
      legalBalls: inn.legalBalls,
      extras: inn.extras,
      strikerId: strikerId,
      nonStrikerId: nonStrikerId,
      currentBowlerId: bowlerId,
      batsmen: batsmen,
      bowlers: bowlers,
      partnershipRuns: inn.partnershipRuns,
      partnershipBalls: inn.partnershipBalls,
      isFreeHitActive: inn.isFreeHitActive,
    );

    final inningsList = List<InningsModel>.from(match.innings);
    inningsList[match.currentInningsIndex] = updatedInnings;

    final updated = match.copyWith(innings: inningsList);
    final overlay = _scoringEngine.buildOverlayForMatch(updated);

    final batch = _firestore.batch();
    batch.update(_matchDoc(matchId), updated.toMap());
    batch.set(
      _matchDoc(matchId).collection('overlay').doc('current'),
      overlay.toMap(),
    );
    await batch.commit();
  }

  Future<MatchModel?> completeMatch(String matchId) async {
    final match = await getMatch(matchId);
    if (match == null) return null;

    final hero = _badgeService.pickMatchHero(match);
    final badgeIds = <String>[];
    for (final inn in match.innings) {
      final badges = _badgeService.evaluateInningsBadges(
        matchId: matchId,
        innings: inn,
        playerNames: {},
      );
      badgeIds.addAll(badges.map((b) => b.id));
    }

    final winnerTeamId = _inferWinnerTeamId(match);
    final resultSummary = hero != null
        ? '${hero.playerName} — ${hero.reason}'
        : _resultText(match, winnerTeamId);

    final completed = match.copyWith(
      status: MatchStatus.completed,
      completedAt: DateTime.now(),
      matchHero: hero,
      playerOfMatchId: hero?.playerId,
      badgeIds: badgeIds,
      winnerTeamId: winnerTeamId,
      resultSummary: resultSummary,
    );

    await _matchDoc(matchId).update(completed.toMap());
    return completed;
  }

  String? _inferWinnerTeamId(MatchModel match) {
    if (match.innings.isEmpty) return null;
    final first = match.innings.first;
    if (match.innings.length < 2) {
      return first.battingTeamId;
    }
    final second = match.innings[1];
    if (second.totalRuns > first.totalRuns) return second.battingTeamId;
    if (first.totalRuns > second.totalRuns) return first.battingTeamId;
    return null;
  }

  String _resultText(MatchModel match, String? winnerId) {
    if (winnerId == null) return 'Match completed';
    if (winnerId == match.teamAId) return '${match.teamAName} won';
    if (winnerId == match.teamBId) return '${match.teamBName} won';
    return 'Match completed';
  }

  Future<void> _commitMatchState({
    required String matchId,
    required Map<String, dynamic> matchData,
    required BallEventModel event,
    required OverlayStateModel overlay,
  }) async {
    final batch = _firestore.batch();
    batch.update(_matchDoc(matchId), matchData);
    batch.set(_ballEvents(matchId).doc(event.id), event.toMap());
    batch.set(
      _matchDoc(matchId).collection('overlay').doc('current'),
      overlay.toMap(),
    );
    await batch.commit();
    final match = MatchModel.fromMap(matchId, matchData);
    await _syncPublicScorecard(match, overlay: overlay);
  }

  Stream<OverlayStateModel?> watchOverlay(String matchId) {
    return _matchDoc(matchId)
        .collection('overlay')
        .doc('current')
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return OverlayStateModel.fromMap(doc.data()!);
    });
  }

  Stream<List<BallEventModel>> watchBallEvents(String matchId) {
    return _ballEvents(matchId)
        .orderBy('sequence')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => BallEventModel.fromMap(d.id, d.data()))
            .toList());
  }

  Future<List<BallEventModel>> getBallEvents(String matchId) async {
    final snap = await _ballEvents(matchId).orderBy('sequence').get();
    return snap.docs
        .map((d) => BallEventModel.fromMap(d.id, d.data()))
        .toList();
  }

  Future<void> startMatch(
    String matchId,
    InningsModel firstInnings, {
    String? scorerId,
  }) async {
    final data = <String, dynamic>{
      'status': MatchStatus.live.name,
      'startedAt': DateTime.now().toIso8601String(),
      'innings': [firstInnings.toMap()],
      'currentInningsIndex': 0,
    };
    if (scorerId != null) {
      data['scorerIds'] = FieldValue.arrayUnion([scorerId]);
    }
    await _matchDoc(matchId).update(data);
  }

  Future<void> addScorer(String matchId, String userId) async {
    await _matchDoc(matchId).update({
      'scorerIds': FieldValue.arrayUnion([userId]),
    });
  }

  /// Mark current innings complete.
  Future<void> endCurrentInnings(String matchId) async {
    final match = await getMatch(matchId);
    if (match == null || match.currentInnings == null) return;

    final inningsList = List<InningsModel>.from(match.innings);
    final idx = match.currentInningsIndex;
    final inn = inningsList[idx];
    inningsList[idx] = InningsModel(
      inningsNumber: inn.inningsNumber,
      battingTeamId: inn.battingTeamId,
      bowlingTeamId: inn.bowlingTeamId,
      status: InningsStatus.completed,
      totalRuns: inn.totalRuns,
      totalWickets: inn.totalWickets,
      legalBalls: inn.legalBalls,
      extras: inn.extras,
      strikerId: inn.strikerId,
      nonStrikerId: inn.nonStrikerId,
      currentBowlerId: inn.currentBowlerId,
      batsmen: inn.batsmen,
      bowlers: inn.bowlers,
      partnershipRuns: inn.partnershipRuns,
      partnershipBalls: inn.partnershipBalls,
      isFreeHitActive: false,
    );

    await _matchDoc(matchId).update({
      'innings': inningsList.map((i) => i.toMap()).toList(),
      'status': MatchStatus.inningsBreak.name,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Start next innings (swap batting/bowling).
  Future<void> startNextInnings(String matchId) async {
    final match = await getMatch(matchId);
    if (match == null || match.innings.isEmpty) return;

    final prev = match.innings.last;
    final nextNumber = prev.inningsNumber + 1;
    final maxInnings = match.rules.maxInnings;
    if (nextNumber > maxInnings) {
      throw StateError('Maximum innings reached');
    }

    final battingId = prev.bowlingTeamId;
    final bowlingId = prev.battingTeamId;

    final nextInnings = InningsModel(
      inningsNumber: nextNumber,
      battingTeamId: battingId,
      bowlingTeamId: bowlingId,
      status: InningsStatus.inProgress,
    );

    final inningsList = [...match.innings, nextInnings];

    await _matchDoc(matchId).update({
      'innings': inningsList.map((i) => i.toMap()).toList(),
      'currentInningsIndex': inningsList.length - 1,
      'status': MatchStatus.live.name,
      'overlayVersion': match.overlayVersion + 1,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  bool canStartNextInnings(MatchModel match) {
    if (match.innings.isEmpty) return false;
    final last = match.innings.last;
    if (last.status != InningsStatus.completed) return false;
    return last.inningsNumber < match.rules.maxInnings;
  }

  InningsScoreSummary? firstInningsTarget(MatchModel match) {
    if (match.innings.isEmpty) return null;
    final first = match.innings.first;
    return InningsScoreSummary(
      runs: first.totalRuns,
      wickets: first.totalWickets,
      teamId: first.battingTeamId,
    );
  }
}

class InningsScoreSummary {
  const InningsScoreSummary({
    required this.runs,
    required this.wickets,
    required this.teamId,
  });

  final int runs;
  final int wickets;
  final String teamId;

  int get target => runs + 1;
}
