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
import '../../domain/scoring/match_completion_policy.dart';
import '../../domain/scoring/innings_completion_policy.dart';
import '../../domain/scoring/scoring_integrity_check.dart';
import '../../domain/scoring/toss_team_policy.dart';
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
    // Always score against latest persisted state (avoids stale index corrupting innings[0]).
    var latest = await getMatch(match.id) ?? match;
    latest = _withChaseTargetBackfill(latest);

    final result = _scoringEngine.recordBall(
      match: latest,
      input: input,
      sequence: sequence,
    );

    final eventId = _uuid.v4();
    final highlight = HighlightUtils.classify(result.event);
    final commentary = result.event.commentary.trim().isEmpty
        ? CommentaryService.forEvent(result.event)
        : result.event.commentary;

    final built = result.event;
    final event = built.copyWith(
      id: eventId,
      commentary: commentary,
      sequence: sequence,
      isHighlight: highlight.isHighlight,
      highlightTag: highlight.tag,
      wagonWheel: input.wagonWheel ?? built.wagonWheel,
      undoGroupId: input.undoGroupId ?? built.undoGroupId,
    );

    await _commitMatchState(
      matchId: match.id,
      matchData: result.match.toMap(),
      event: event,
      overlay: result.overlay,
    );

    final allEvents = await fetchBallEvents(match.id);
    ScoringIntegrityCheck.assertProjectionMatchesEvents(
      match: result.match,
      allEvents: allEvents,
      context: 'recordBall',
    );

    return ScoringInput(match: result.match, event: event, overlay: result.overlay);
  }

  /// Ensures chase innings have a fixed target from completed 1st innings.
  MatchModel _withChaseTargetBackfill(MatchModel match) {
    final cur = match.currentInnings;
    if (cur == null || cur.inningsNumber < 2 || cur.isSuperOver) return match;
    if (cur.targetRuns != null && cur.targetRuns! > 0) return match;

    final first = InningsCompletionPolicy.firstInnings(match);
    if (first == null || first.status != InningsStatus.completed) return match;

    final inningsList = List<InningsModel>.from(match.innings);
    final idx = match.currentInningsIndex;
    if (idx < 0 || idx >= inningsList.length) return match;

    inningsList[idx] = InningsModel(
      inningsNumber: cur.inningsNumber,
      battingTeamId: cur.battingTeamId,
      bowlingTeamId: cur.bowlingTeamId,
      status: cur.status,
      totalRuns: cur.totalRuns,
      totalWickets: cur.totalWickets,
      legalBalls: cur.legalBalls,
      extras: cur.extras,
      strikerId: cur.strikerId,
      nonStrikerId: cur.nonStrikerId,
      currentBowlerId: cur.currentBowlerId,
      batsmen: cur.batsmen,
      bowlers: cur.bowlers,
      partnershipRuns: cur.partnershipRuns,
      partnershipBalls: cur.partnershipBalls,
      isFreeHitActive: cur.isFreeHitActive,
      targetRuns: first.totalRuns + 1,
      isSuperOver: cur.isSuperOver,
    );

    return match.copyWith(innings: inningsList);
  }

  /// Deletes last ball event and replays remaining events from base innings.
  Future<MatchModel?> undoLastBall(String matchId) async {
    final match = await getMatch(matchId);
    if (match == null || match.currentInnings == null) return null;

    if (match.status == MatchStatus.inningsBreak) {
      throw StateError('Cannot undo after innings is marked complete');
    }
    if (match.currentInnings!.status == InningsStatus.completed) {
      throw StateError('Cannot undo after innings is marked complete');
    }

    final allEvents = await fetchBallEvents(matchId);
    if (allEvents.isEmpty) return match;

    final currentInn = match.currentInnings!;
    final last = allEvents.last;
    if (last.inningsNumber != currentInn.inningsNumber) {
      throw StateError('Nothing to undo in current innings');
    }

    final groupId = last.undoGroupId?.trim();
    final List<BallEventModel> toRemove;
    if (groupId != null && groupId.isNotEmpty) {
      toRemove = [];
      for (var i = allEvents.length - 1; i >= 0; i--) {
        if (allEvents[i].undoGroupId == groupId) {
          toRemove.insert(0, allEvents[i]);
        } else {
          break;
        }
      }
    } else {
      toRemove = [last];
    }

    for (final e in toRemove) {
      allEvents.remove(e);
    }
    final inningsEvents = allEvents
        .where((e) => e.inningsNumber == currentInn.inningsNumber)
        .toList();

    final preservedPriorInnings = List<InningsModel>.from(match.innings);
    final base = _scoringEngine.baseInningsFrom(
      currentInn,
      events: inningsEvents,
    );
    var replayed = _scoringEngine.replayInnings(
      match: match,
      baseInnings: base,
      events: inningsEvents,
    );

    // Never mutate completed prior innings during current-innings replay.
    if (match.currentInningsIndex > 0) {
      final inningsList = List<InningsModel>.from(replayed.innings);
      for (var i = 0; i < match.currentInningsIndex; i++) {
        inningsList[i] = preservedPriorInnings[i];
      }
      replayed = replayed.copyWith(innings: inningsList);
    }
    final overlay = _scoringEngine.buildOverlayForMatch(replayed);

    final batch = _firestore.batch();
    for (final e in toRemove) {
      batch.delete(_ballEvents(matchId).doc(e.id));
    }
    batch.update(_matchDoc(matchId), replayed.toMap());
    batch.set(
      _matchDoc(matchId).collection('overlay').doc('current'),
      overlay.toMap(),
    );
    await batch.commit();
    await _syncPublicScorecard(replayed, overlay: overlay);

    ScoringIntegrityCheck.assertProjectionMatchesEvents(
      match: replayed,
      allEvents: allEvents,
      context: 'undoLastBall',
    );

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
      targetRuns: inn.targetRuns,
      isSuperOver: inn.isSuperOver,
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

    final result = MatchCompletionPolicy.compute(match);
    final resultSummary = hero != null
        ? '${hero.playerName} — ${hero.reason}'
        : result.summary;

    final completed = match.copyWith(
      status: MatchStatus.completed,
      completedAt: DateTime.now(),
      matchHero: hero,
      playerOfMatchId: hero?.playerId,
      badgeIds: badgeIds,
      winnerTeamId: result.winnerTeamId,
      resultSummary: resultSummary,
    );

    await _matchDoc(matchId).update(completed.toMap());
    return completed;
  }

  /// After a tied match when [superOverEnabled], start super over innings for team A.
  Future<void> startSuperOver(String matchId) async {
    final match = await getMatch(matchId);
    if (match == null || match.innings.length < 2) return;

    final regular = match.innings.where((i) => !i.isSuperOver).toList();
    if (regular.length < 2) return;

    final first = regular[0];
    final second = regular[1];
    if (first.totalRuns != second.totalRuns) {
      throw StateError('Super over only available on a tie');
    }

    final battingId = match.teamAId ?? first.battingTeamId;
    final bowlingId = match.teamBId ?? first.bowlingTeamId;

    final superInnings = InningsModel(
      inningsNumber: match.innings.length + 1,
      battingTeamId: battingId,
      bowlingTeamId: bowlingId,
      status: InningsStatus.notStarted,
      isSuperOver: true,
    );

    await _matchDoc(matchId).update({
      'innings': [...match.innings.map((i) => i.toMap()), superInnings.toMap()],
      'currentInningsIndex': match.innings.length,
      'status': MatchStatus.inningsBreak.name,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Second super over innings (team B bats).
  Future<void> startSecondSuperOver(String matchId) async {
    final match = await getMatch(matchId);
    if (match == null) return;

    final superOvers = match.innings.where((i) => i.isSuperOver).toList();
    if (superOvers.isEmpty) return;

    final firstSo = superOvers.first;
    final target = firstSo.totalRuns + 1;

    final battingId = firstSo.bowlingTeamId;
    final bowlingId = firstSo.battingTeamId;

    final secondSo = InningsModel(
      inningsNumber: match.innings.length + 1,
      battingTeamId: battingId,
      bowlingTeamId: bowlingId,
      status: InningsStatus.notStarted,
      isSuperOver: true,
      targetRuns: target,
    );

    await _matchDoc(matchId).update({
      'innings': [...match.innings.map((i) => i.toMap()), secondSo.toMap()],
      'currentInningsIndex': match.innings.length,
      'status': MatchStatus.inningsBreak.name,
      'updatedAt': DateTime.now().toIso8601String(),
    });
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
    final existing = await getMatch(matchId);
    if (existing != null &&
        (existing.innings.length > 1 ||
            existing.innings.any((i) => i.status == InningsStatus.completed))) {
      throw StateError(
        'Cannot restart match — use lineup update for innings in progress',
      );
    }

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

  /// Correct toss winner's bat/bowl choice; resets innings 1 with swapped teams.
  Future<MatchModel> updateTossElection(
    String matchId, {
    required bool winnerBatsFirst,
  }) async {
    final match = await getMatch(matchId);
    if (match == null) throw StateError('Match not found');

    final setup = match.setup;
    if (setup == null || !setup.tossReady) {
      throw StateError('Toss has not been recorded');
    }
    if (match.status == MatchStatus.completed) {
      throw StateError('Cannot change toss after the match is completed');
    }
    if (match.innings.length != 1) {
      throw StateError('Toss can only be changed during the first innings');
    }

    final inn = match.innings.first;
    if (inn.inningsNumber != 1 ||
        inn.isSuperOver ||
        inn.status == InningsStatus.completed) {
      throw StateError('Toss can only be changed during the first innings');
    }

    if (inn.legalBalls > 0 ||
        inn.totalRuns > 0 ||
        inn.totalWickets > 0 ||
        inn.extras > 0) {
      throw StateError(
        'Toss can only be changed before the first ball is scored',
      );
    }

    if (setup.tossWinnerBatsFirst == winnerBatsFirst) {
      return match;
    }

    final updatedSetup = setup.copyWith(tossWinnerBatsFirst: winnerBatsFirst);
    final matchWithToss = match.copyWith(setup: updatedSetup);
    final teams = TossTeamPolicy.firstInningsTeams(matchWithToss);

    final updatedInn = InningsModel(
      inningsNumber: 1,
      battingTeamId: teams.battingTeamId,
      bowlingTeamId: teams.bowlingTeamId,
      status: InningsStatus.notStarted,
    );

    await _matchDoc(matchId).update({
      'tossWinnerBatsFirst': winnerBatsFirst,
      'innings': [updatedInn.toMap()],
      'currentInningsIndex': 0,
      'status': MatchStatus.tossCompleted.name,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    final fresh = await getMatch(matchId);
    if (fresh == null) throw StateError('Match not found after toss update');
    return fresh;
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
      targetRuns: inn.targetRuns,
      isSuperOver: inn.isSuperOver,
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
    final superOvers = match.innings.where((i) => i.isSuperOver).length;
    final regularCount =
        match.innings.where((i) => !i.isSuperOver).length;

    if (prev.isSuperOver && superOvers == 1) {
      await startSecondSuperOver(matchId);
      return;
    }

    final nextNumber = prev.inningsNumber + 1;
    final maxInnings = match.rules.maxInnings;
    if (!prev.isSuperOver && regularCount >= maxInnings) {
      throw StateError('Maximum innings reached');
    }

    final chaseTeams = TossTeamPolicy.chaseInningsTeams(prev);
    final battingId = chaseTeams.battingTeamId;
    final bowlingId = chaseTeams.bowlingTeamId;

    int? targetRuns;
    if (!prev.isSuperOver && regularCount == 1) {
      targetRuns = prev.totalRuns + 1;
    }

    final nextInnings = InningsModel(
      inningsNumber: nextNumber,
      battingTeamId: battingId,
      bowlingTeamId: bowlingId,
      status: InningsStatus.notStarted,
      targetRuns: targetRuns,
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

    if (MatchCompletionPolicy.shouldOfferSuperOver(match)) return true;

    final superOvers = match.innings.where((i) => i.isSuperOver).length;
    if (last.isSuperOver && superOvers == 1) return true;

    final regularCount =
        match.innings.where((i) => !i.isSuperOver).length;
    return regularCount < match.rules.maxInnings;
  }

  InningsScoreSummary? firstInningsTarget(MatchModel match) {
    InningsModel? first;
    for (final inn in match.innings) {
      if (inn.inningsNumber == 1) {
        first = inn;
        break;
      }
    }
    first ??= match.innings.isNotEmpty ? match.innings.first : null;
    if (first == null || first.status != InningsStatus.completed) return null;
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
