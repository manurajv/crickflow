import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/enums.dart';
import '../../data/models/ball_event_model.dart';
import '../../data/models/innings_model.dart';
import '../../data/models/location_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/over_metadata_model.dart';
import '../../data/models/over_note_model.dart';
import '../../data/models/overlay_state_model.dart';
import '../../data/models/scorer_transfer_models.dart';
import '../../core/utils/highlight_utils.dart';
import '../../core/utils/match_public_id_utils.dart';
import '../../core/utils/match_scorer_utils.dart';
import '../../data/models/match_break_model.dart';
import '../../data/models/match_rules_model.dart';
import '../../data/models/match_player_snapshot.dart';
import '../../data/models/match_setup_draft_models.dart';
import '../../domain/services/badge_service.dart';
import '../../domain/services/commentary_service.dart';
import '../../domain/services/scoring_engine.dart';
import '../../domain/scoring/match_completion_policy.dart';
import '../../domain/scoring/innings_completion_policy.dart';
import '../../domain/scoring/scoring_integrity_check.dart';
import '../../domain/scoring/toss_team_policy.dart';
import '../local/match_local_store.dart';
import '../local/pending_sync_action.dart';
import '../services/offline_sync_service.dart';
import '../services/public_scorecard_sync.dart';

class MatchRepository {
  MatchRepository({
    FirebaseFirestore? firestore,
    ScoringEngine? scoringEngine,
    BadgeService? badgeService,
    PublicScorecardSync? publicScorecardSync,
    MatchLocalStore? localStore,
    OfflineSyncService? syncService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _scoringEngine = scoringEngine ?? ScoringEngine(),
        _badgeService = badgeService ?? BadgeService(),
        _publicSync = publicScorecardSync ?? PublicScorecardSync(),
        _localStore = localStore,
        _syncService = syncService,
        _uuid = const Uuid();

  final FirebaseFirestore _firestore;
  final ScoringEngine _scoringEngine;
  final BadgeService _badgeService;
  final PublicScorecardSync _publicSync;
  final MatchLocalStore? _localStore;
  final OfflineSyncService? _syncService;
  final Uuid _uuid;

  bool get _offlineEnabled => _localStore != null && _syncService != null;

  CollectionReference<Map<String, dynamic>> get _matches =>
      _firestore.collection(AppConstants.matchesCollection);

  DocumentReference<Map<String, dynamic>> _matchDoc(String id) =>
      _matches.doc(id);

  CollectionReference<Map<String, dynamic>> _ballEvents(String matchId) =>
      _matchDoc(matchId).collection('ball_events');

  CollectionReference<Map<String, dynamic>> _activityLogs(String matchId) =>
      _matchDoc(matchId).collection('activity_logs');

  bool _isActiveScoring(MatchModel match) =>
      match.status == MatchStatus.live ||
      match.status == MatchStatus.inningsBreak;

  Future<MatchModel?> _getMatchFromFirestore(String id) async {
    try {
      final doc = await _matches.doc(id).get();
      if (!doc.exists) return null;
      return MatchModel.fromMap(doc.id, doc.data()!);
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') {
        final cached =
            await _matches.doc(id).get(const GetOptions(source: Source.cache));
        if (!cached.exists) return null;
        return MatchModel.fromMap(cached.id, cached.data()!);
      }
      rethrow;
    }
  }

  Future<List<BallEventModel>> _fetchBallEventsFromFirestore(
    String matchId,
  ) async {
    final snap = await _ballEvents(matchId).orderBy('sequence').get();
    return snap.docs
        .map((d) => BallEventModel.fromMap(d.id, d.data()))
        .toList();
  }

  Future<void> _persistMatchLocally(
    MatchModel match, {
    OverlayStateModel? overlay,
  }) async {
    final local = _localStore;
    if (local == null) return;
    await local.saveSnapshot(
      matchId: match.id,
      match: match,
      overlay: overlay,
    );
  }

  Future<void> _enqueueMatchUpdate(
    MatchModel match, {
    List<String> fieldDeletes = const [],
  }) async {
    final sync = _syncService;
    final local = _localStore;
    if (sync == null || local == null) {
      final data = match.toMap();
      for (final field in fieldDeletes) {
        data[field] = FieldValue.delete();
      }
      await _matchDoc(match.id).update(data);
      await _syncPublicScorecard(match);
      return;
    }
    await _persistMatchLocally(match);
    await sync.enqueue(
      sync.newAction(
        matchId: match.id,
        type: SyncActionType.matchUpdate,
        payload: {
          'matchData': match.toMap(),
          if (fieldDeletes.isNotEmpty) 'fieldDeletes': fieldDeletes,
        },
      ),
    );
  }

  Future<void> _enqueueMatchPatch(
    String matchId,
    Map<String, dynamic> patch,
  ) async {
    final existing = await getMatch(matchId);
    if (existing == null) throw StateError('Match not found');
    final merged = MatchModel.fromMap(
      matchId,
      {
        ...existing.toMap(),
        ...patch,
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );
    await _enqueueMatchUpdate(merged);
  }

  Future<void> _enqueueFirestoreBatch({
    required String matchId,
    required List<FirestoreBatchOp> operations,
  }) async {
    final sync = _syncService;
    if (sync == null) {
      final batch = _firestore.batch();
      for (final op in operations) {
        final ref = _resolveBatchRef(op);
        switch (op.op) {
          case 'set':
            batch.set(ref, op.data ?? {}, SetOptions(merge: op.merge));
          case 'update':
            batch.update(ref, op.data ?? {});
          case 'delete':
            batch.delete(ref);
        }
      }
      await batch.commit();
      return;
    }
    await sync.enqueue(
      sync.newAction(
        matchId: matchId,
        type: SyncActionType.firestoreBatch,
        payload: {
          'operations': operations.map((o) => o.toMap()).toList(),
        },
      ),
    );
  }

  DocumentReference<Map<String, dynamic>> _resolveBatchRef(
    FirestoreBatchOp op,
  ) {
    var ref = _firestore.collection(op.collection).doc(op.docId);
    if (op.subcollection != null && op.subDocId != null) {
      ref = ref.collection(op.subcollection!).doc(op.subDocId!);
    }
    return ref;
  }

  Future<void> _ensureLocalSnapshot(String matchId) async {
    final local = _localStore;
    if (local == null || local.hasLocalSnapshot(matchId)) return;
    final remote = await _getMatchFromFirestore(matchId);
    if (remote == null) return;
    final events = await _fetchBallEventsFromFirestore(matchId);
    OverlayStateModel? overlay;
    try {
      final overlayDoc = await _matchDoc(matchId)
          .collection('overlay')
          .doc('current')
          .get();
      if (overlayDoc.exists) {
        overlay = OverlayStateModel.fromMap(overlayDoc.data()!);
      }
    } catch (_) {}
    await local.importFromRemote(
      match: remote,
      events: events,
      overlay: overlay,
    );
  }

  Stream<MatchModel?> _watchMatchRemote(String id) {
    return _matches.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return MatchModel.fromMap(doc.id, doc.data()!);
    });
  }

  Future<String> createMatch(MatchModel match) async {
    final id = match.id.isEmpty ? _uuid.v4() : match.id;
    await _matches.doc(id).set(match.toMap());
    return id;
  }

  Future<void> deleteMatch(String matchId) async {
    await _matches.doc(matchId).delete();
  }

  Future<void> updateMatch(MatchModel match) async {
    await _enqueueMatchUpdate(match);
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
    final local = _localStore;
    if (local != null) {
      final cached = await local.getMatch(id);
      if (cached != null) return cached;
    }
    return _getMatchFromFirestore(id);
  }

  Stream<MatchModel?> watchMatch(String id) {
    if (!_offlineEnabled) return _watchMatchRemote(id);

    final controller = StreamController<MatchModel?>.broadcast();
    MatchModel? localMatch;
    MatchModel? remoteMatch;

    void emit() {
      if (localMatch != null &&
          (_localStore!.hasPendingSync(id) || _isActiveScoring(localMatch!))) {
        controller.add(localMatch);
      } else {
        controller.add(remoteMatch ?? localMatch);
      }
    }

    final localSub = _localStore!.watchMatch(id).listen((match) {
      localMatch = match;
      emit();
    });
    final remoteSub = _watchMatchRemote(id).listen((match) {
      remoteMatch = match;
      emit();
    });
    controller.onCancel = () {
      localSub.cancel();
      remoteSub.cancel();
    };
    return controller.stream;
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

  Future<List<MatchModel>> fetchHeadToHeadMatches({
    required String teamAId,
    required String teamBId,
    int limit = 50,
  }) async {
    if (teamAId.isEmpty || teamBId.isEmpty) return const [];

    final snap = await _matches
        .where('status', isEqualTo: MatchStatus.completed.name)
        .orderBy('completedAt', descending: true)
        .limit(120)
        .get();

    return snap.docs
        .map((d) => MatchModel.fromMap(d.id, d.data()))
        .where(
          (m) =>
              (m.teamAId == teamAId && m.teamBId == teamBId) ||
              (m.teamAId == teamBId && m.teamBId == teamAId),
        )
        .take(limit)
        .toList();
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
    final local = _localStore;
    if (local != null && local.hasLocalSnapshot(matchId)) {
      return local.getBallEvents(matchId);
    }
    return _fetchBallEventsFromFirestore(matchId);
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
    OverNoteModel? overNote,
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

    await _ensureLocalSnapshot(match.id);

    await _commitMatchState(
      matchId: match.id,
      matchData: _matchDataWithOverLifecycle(
        result.match,
        overNote: overNote,
        overMetadata: result.overMetadata,
        ballEventId: eventId,
      ),
      event: event,
      overlay: result.overlay,
    );

    var allEvents = await fetchBallEvents(match.id);
    if (!allEvents.any((e) => e.id == event.id)) {
      allEvents = [...allEvents, event]
        ..sort((a, b) => a.sequence.compareTo(b.sequence));
    }
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
      targetRuns: match.targetState.pendingChaseTarget ?? first.totalRuns + 1,
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
    BallEventModel? creaseSeed;
    if (inningsEvents.isEmpty && toRemove.isNotEmpty) {
      creaseSeed = toRemove.firstWhere(
        (e) =>
            e.eventType != BallEventType.lineupChange &&
            e.eventType != BallEventType.wicketKeeperChange &&
            e.eventType != BallEventType.endOver,
        orElse: () => toRemove.first,
      );
    }
    final base = _scoringEngine.baseInningsFrom(
      currentInn,
      events: inningsEvents,
      openingStrikerId: creaseSeed?.strikerId,
      openingNonStrikerId: creaseSeed?.nonStrikerId,
      openingBowlerId: creaseSeed?.bowlerId,
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
    final removedIds = toRemove.map((e) => e.id).toSet();
    final keptNotes = match.overNotes
        .where(
          (n) => n.ballEventId == null || !removedIds.contains(n.ballEventId),
        )
        .toList();
    final keptMetadata = match.overMetadata
        .where(
          (m) => m.ballEventId == null || !removedIds.contains(m.ballEventId),
        )
        .toList();
    replayed = replayed.copyWith(
      overNotes: keptNotes,
      overMetadata: keptMetadata,
    );

    final overlay = _scoringEngine.buildOverlayForMatch(replayed);

    await _localStore?.removeBallEvents(
      matchId,
      toRemove.map((e) => e.id),
    );
    await _persistMatchLocally(replayed, overlay: overlay);
    await _localStore?.setBallEvents(matchId, allEvents);

    final sync = _syncService;
    if (sync == null) {
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
    } else {
      await sync.enqueue(
        sync.newAction(
          matchId: matchId,
          type: SyncActionType.undoBalls,
          payload: {
            'matchData': replayed.toMap(),
            'overlayData': overlay.toMap(),
            'deletedEventIds': toRemove.map((e) => e.id).toList(),
          },
        ),
      );
    }

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
      status: inn.status == InningsStatus.notStarted
          ? InningsStatus.inProgress
          : inn.status,
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

    await _persistMatchLocally(updated, overlay: overlay);
    final sync = _syncService;
    if (sync == null) {
      final batch = _firestore.batch();
      batch.update(_matchDoc(matchId), updated.toMap());
      batch.set(
        _matchDoc(matchId).collection('overlay').doc('current'),
        overlay.toMap(),
      );
      await batch.commit();
    } else {
      await sync.enqueue(
        sync.newAction(
          matchId: matchId,
          type: SyncActionType.matchOverlay,
          payload: {
            'matchData': updated.toMap(),
            'overlayData': overlay.toMap(),
          },
        ),
      );
    }
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
    final winnerId = match.winnerTeamId ?? result.winnerTeamId;
    final summary = match.resultSummary.isNotEmpty
        ? match.resultSummary
        : result.summary;

    final completed = match.copyWith(
      status: MatchStatus.completed,
      completedAt: DateTime.now(),
      matchHero: hero,
      playerOfMatchId: hero?.playerId,
      badgeIds: badgeIds,
      winnerTeamId: winnerId,
      resultSummary: summary,
    );

    await _enqueueMatchUpdate(completed);
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

    await _enqueueMatchPatch(matchId, {
      'innings': [...match.innings.map((i) => i.toMap()), superInnings.toMap()],
      'currentInningsIndex': match.innings.length,
      'status': MatchStatus.inningsBreak.name,
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

    await _enqueueMatchPatch(matchId, {
      'innings': [...match.innings.map((i) => i.toMap()), secondSo.toMap()],
      'currentInningsIndex': match.innings.length,
      'status': MatchStatus.inningsBreak.name,
    });
  }

  Map<String, dynamic> _matchDataWithOverLifecycle(
    MatchModel match, {
    OverNoteModel? overNote,
    OverMetadataModel? overMetadata,
    required String ballEventId,
  }) {
    var data = match.toMap();
    if (overNote != null) {
      final notes = List<Map<String, dynamic>>.from(
        data['overNotes'] as List? ?? [],
      );
      notes.add(
        overNote.copyWith(ballEventId: ballEventId).toMap(),
      );
      data['overNotes'] = notes;
    }
    if (overMetadata != null) {
      final metadata = overMetadata.copyWith(
        ballEventId: ballEventId,
        reason: overNote?.reason ?? overMetadata.reason,
      );
      final list = List<Map<String, dynamic>>.from(
        data['overMetadata'] as List? ?? [],
      );
      list.add(metadata.toMap());
      data['overMetadata'] = list;
    }
    return data;
  }

  Future<void> _commitMatchState({
    required String matchId,
    required Map<String, dynamic> matchData,
    required BallEventModel event,
    required OverlayStateModel overlay,
  }) async {
    final match = MatchModel.fromMap(matchId, matchData);
    await _localStore?.appendBallEvent(matchId, event);
    await _persistMatchLocally(match, overlay: overlay);

    final sync = _syncService;
    if (sync == null) {
      final batch = _firestore.batch();
      batch.update(_matchDoc(matchId), matchData);
      batch.set(_ballEvents(matchId).doc(event.id), event.toMap());
      batch.set(
        _matchDoc(matchId).collection('overlay').doc('current'),
        overlay.toMap(),
      );
      await batch.commit();
      await _syncPublicScorecard(match, overlay: overlay);
      return;
    }

    await sync.enqueue(
      sync.newAction(
        matchId: matchId,
        type: SyncActionType.ballCommit,
        payload: {
          'matchData': matchData,
          'eventId': event.id,
          'eventData': event.toMap(),
          'overlayData': overlay.toMap(),
        },
      ),
    );
  }

  Stream<OverlayStateModel?> watchOverlay(String matchId) {
    if (!_offlineEnabled) {
      return _matchDoc(matchId)
          .collection('overlay')
          .doc('current')
          .snapshots()
          .map((doc) {
        if (!doc.exists) return null;
        return OverlayStateModel.fromMap(doc.data()!);
      });
    }

    final controller = StreamController<OverlayStateModel?>.broadcast();
    OverlayStateModel? localOverlay;
    OverlayStateModel? remoteOverlay;

    void emit() {
      if (_localStore!.hasPendingSync(matchId) || localOverlay != null) {
        controller.add(localOverlay ?? remoteOverlay);
      } else {
        controller.add(remoteOverlay ?? localOverlay);
      }
    }

    final localSub = _localStore!.watchOverlay(matchId).listen((overlay) {
      localOverlay = overlay;
      emit();
    });
    final remoteSub = _matchDoc(matchId)
        .collection('overlay')
        .doc('current')
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return OverlayStateModel.fromMap(doc.data()!);
    }).listen((overlay) {
      remoteOverlay = overlay;
      emit();
    });
    controller.onCancel = () {
      localSub.cancel();
      remoteSub.cancel();
    };
    return controller.stream;
  }

  Stream<List<BallEventModel>> watchBallEvents(String matchId) {
    if (!_offlineEnabled) {
      return _ballEvents(matchId)
          .orderBy('sequence')
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => BallEventModel.fromMap(d.id, d.data()))
              .toList());
    }

    final controller = StreamController<List<BallEventModel>>.broadcast();
    List<BallEventModel> localEvents = [];
    List<BallEventModel> remoteEvents = [];

    void emit() {
      if (_localStore!.hasLocalSnapshot(matchId) &&
          (_localStore!.hasPendingSync(matchId) || localEvents.isNotEmpty)) {
        controller.add(localEvents);
      } else {
        controller.add(
          remoteEvents.isNotEmpty ? remoteEvents : localEvents,
        );
      }
    }

    final localSub = _localStore!.watchBallEvents(matchId).listen((events) {
      localEvents = events;
      emit();
    });
    final remoteSub = _ballEvents(matchId)
        .orderBy('sequence')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => BallEventModel.fromMap(d.id, d.data()))
            .toList())
        .listen((events) {
      remoteEvents = events;
      emit();
    });
    controller.onCancel = () {
      localSub.cancel();
      remoteSub.cancel();
    };
    return controller.stream;
  }

  Future<List<BallEventModel>> getBallEvents(String matchId) async {
    return fetchBallEvents(matchId);
  }

  Future<void> startMatch(
    String matchId,
    InningsModel firstInnings, {
    String? scorerId,
    String? scorerName,
    String? scorerPhoto,
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
    if (existing == null ||
        existing.publicMatchId == null ||
        existing.publicMatchId!.isEmpty) {
      data['publicMatchId'] = generatePublicMatchId();
    }
    if (scorerId != null) {
      final existing = await getMatch(matchId);
      final scorerUserIds = <String>{scorerId};
      if (existing != null) {
        if (existing.scorer1UserId != null &&
            existing.scorer1UserId!.isNotEmpty) {
          scorerUserIds.add(existing.scorer1UserId!);
        }
        if (existing.scorer2UserId != null &&
            existing.scorer2UserId!.isNotEmpty) {
          scorerUserIds.add(existing.scorer2UserId!);
        }
        for (final id in existing.scorerIds) {
          if (id.isNotEmpty) scorerUserIds.add(id);
        }
      }
      data['scorerIds'] = scorerUserIds.toList();
      data['currentScorerId'] = scorerId;
      if (scorerName != null && scorerName.isNotEmpty) {
        data['currentScorerName'] = scorerName;
      }
      if (scorerPhoto != null && scorerPhoto.isNotEmpty) {
        data['currentScorerPhoto'] = scorerPhoto;
      }
      data['scorerOwnershipToken'] = _uuid.v4();
      data['lastScorerTransferAt'] = DateTime.now().toIso8601String();
    }
    await _enqueueMatchPatch(matchId, data);
    final started = await getMatch(matchId);
    if (started != null) {
      await _ensureLocalSnapshot(matchId);
      final events = await _localStore?.getBallEvents(matchId) ?? [];
      await _localStore?.importFromRemote(
        match: started,
        events: events,
        overlay: await _localStore?.getOverlay(matchId),
      );
    }
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
    final match = await getMatch(matchId);
    if (match == null) throw StateError('Match not found');
    final scorerIds = <String>{...match.scorerIds, userId}.toList();
    await _enqueueMatchPatch(matchId, {'scorerIds': scorerIds});
  }

  /// Ensures ownership token exists (for QR takeover on legacy matches).
  Future<String> ensureScorerOwnershipToken(String matchId) async {
    final match = await getMatch(matchId);
    if (match == null) throw StateError('Match not found');
    final existing = match.scorerOwnershipToken;
    if (existing != null && existing.isNotEmpty) return existing;

    final token = _uuid.v4();
    try {
      await _matchDoc(matchId).update({
        'scorerOwnershipToken': token,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') {
        // Offline — use ephemeral token for display; sync when online.
        return token;
      }
      rethrow;
    }
    return token;
  }

  Future<void> _appendActivityLog(
    String matchId, {
    required String message,
    required String createdBy,
    String type = 'scorer_transfer',
  }) async {
    await _activityLogs(matchId).add({
      'message': message,
      'type': type,
      'createdBy': createdBy,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Transfer active scoring ownership to another registered user.
  Future<void> transferScorerOwnership({
    required String matchId,
    required String fromUserId,
    required String fromUserName,
    required String toUserId,
    required String toUserName,
    String? toUserPhoto,
    String? ownershipToken,
  }) async {
    final match = await getMatch(matchId);
    if (match == null) throw StateError('Match not found');

    if (ownershipToken != null &&
        match.scorerOwnershipToken != null &&
        match.scorerOwnershipToken != ownershipToken) {
      throw StateError('Invalid ownership token');
    }

    final now = DateTime.now();
    final record = ScorerTransferRecord(
      fromUserId: fromUserId,
      fromUserName: fromUserName,
      toUserId: toUserId,
      toUserName: toUserName,
      timestamp: now,
    );
    final history = [...match.scorerTransferHistory, record];
    final scorerIds = <String>{...match.scorerIds, toUserId}.toList();

    await _enqueueMatchPatch(matchId, {
      'currentScorerId': toUserId,
      'currentScorerName': toUserName,
      if (toUserPhoto != null) 'currentScorerPhoto': toUserPhoto,
      'lastScorerTransferAt': now.toIso8601String(),
      'scorerTransferHistory': history.map((e) => e.toMap()).toList(),
      'scorerIds': scorerIds,
    });

    if (_offlineEnabled) {
      await _enqueueFirestoreBatch(
        matchId: matchId,
        operations: [
          FirestoreBatchOp(
            op: 'set',
            collection: AppConstants.matchesCollection,
            docId: matchId,
            subcollection: 'activity_logs',
            subDocId: _uuid.v4(),
            data: {
              'message':
                  'Scoring transferred from $fromUserName to $toUserName',
              'type': 'scorer_transfer',
              'createdBy': fromUserId,
              'createdAt': now.toIso8601String(),
            },
          ),
        ],
      );
    } else {
      await _appendActivityLog(
        matchId,
        message: 'Scoring transferred from $fromUserName to $toUserName',
        createdBy: fromUserId,
      );
    }
  }

  /// Replace Scorer 1 or Scorer 2 on a live match (assigned scorers only).
  Future<void> replaceAssignedScorer({
    required String matchId,
    required int slotIndex,
    required MatchOfficialEntry replacement,
    required String actorUserId,
    required String actorName,
  }) async {
    if (slotIndex < 0 || slotIndex > 1) {
      throw ArgumentError('slotIndex must be 0 (Scorer 1) or 1 (Scorer 2)');
    }
    final match = await getMatch(matchId);
    if (match == null) throw StateError('Match not found');

    if (!isAssignedMatchScorer(match: match, userId: actorUserId)) {
      throw StateError('Only assigned scorers can change scorer assignments');
    }

    final setup = match.setup ?? const MatchSetupData();
    final scorers = List<MatchOfficialEntry>.from(setup.scorers);
    while (scorers.length <= slotIndex) {
      scorers.add(MatchOfficialEntry(name: '', slotLabel: ''));
    }
    final previous = scorers[slotIndex];
    scorers[slotIndex] = replacement.copyWith(
      slotLabel: slotIndex == 0 ? 'Scorer 1' : 'Scorer 2',
    );
    final updatedSetup = setup.copyWith(scorers: scorers);

    final scorerUserIds = <String>[];
    for (final scorer in scorers) {
      final uid = scorer.userId;
      if (uid != null && uid.isNotEmpty && !scorerUserIds.contains(uid)) {
        scorerUserIds.add(uid);
      }
    }

    final now = DateTime.now();
    final record = ScorerTransferRecord(
      fromUserId: previous.userId ?? '',
      fromUserName: previous.name.isNotEmpty ? previous.name : 'Previous scorer',
      toUserId: replacement.userId ?? '',
      toUserName: replacement.name,
      timestamp: now,
    );
    final history = [...match.scorerTransferHistory, record];

    await _enqueueMatchPatch(matchId, {
      ...updatedSetup.toMap(),
      'scorerIds': scorerUserIds,
      'scorerTransferHistory': history.map((e) => e.toMap()).toList(),
      'lastScorerTransferAt': now.toIso8601String(),
    });

    if (_offlineEnabled) {
      await _enqueueFirestoreBatch(
        matchId: matchId,
        operations: [
          FirestoreBatchOp(
            op: 'set',
            collection: AppConstants.matchesCollection,
            docId: matchId,
            subcollection: 'activity_logs',
            subDocId: _uuid.v4(),
            data: {
              'message':
                  '$actorName assigned ${replacement.name} as Scorer ${slotIndex + 1}',
              'type': 'scorer_transfer',
              'createdBy': actorUserId,
              'createdAt': now.toIso8601String(),
            },
          ),
        ],
      );
    } else {
      await _appendActivityLog(
        matchId,
        message:
            '$actorName assigned ${replacement.name} as Scorer ${slotIndex + 1}',
        createdBy: actorUserId,
      );
    }
  }

  /// Accept takeover via QR — caller becomes active scorer.
  Future<void> acceptScorerTakeover({
    required String matchId,
    required String newUserId,
    required String newUserName,
    String? newUserPhoto,
    required String ownershipToken,
  }) async {
    final match = await getMatch(matchId);
    if (match == null) throw StateError('Match not found');

    final token = match.scorerOwnershipToken;
    if (token == null || token.isEmpty || token != ownershipToken) {
      throw StateError('Invalid or expired QR code');
    }

    final fromId = match.currentScorerId ?? match.createdBy ?? '';
    final fromName = match.currentScorerName.isNotEmpty
        ? match.currentScorerName
        : 'Previous scorer';

    await transferScorerOwnership(
      matchId: matchId,
      fromUserId: fromId,
      fromUserName: fromName,
      toUserId: newUserId,
      toUserName: newUserName,
      toUserPhoto: newUserPhoto,
      ownershipToken: ownershipToken,
    );
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

    await _enqueueMatchPatch(matchId, {
      'innings': inningsList.map((i) => i.toMap()).toList(),
      'status': MatchStatus.inningsBreak.name,
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
      final pending = match.targetState.pendingChaseTarget;
      targetRuns = pending != null && pending > 0
          ? pending
          : prev.totalRuns + 1;
    }

    final nextInnings = InningsModel(
      inningsNumber: nextNumber,
      battingTeamId: battingId,
      bowlingTeamId: bowlingId,
      status: InningsStatus.notStarted,
      targetRuns: targetRuns,
    );

    final inningsList = [...match.innings, nextInnings];

    await _enqueueMatchPatch(matchId, {
      'innings': inningsList.map((i) => i.toMap()).toList(),
      'currentInningsIndex': inningsList.length - 1,
      'status': MatchStatus.live.name,
      'overlayVersion': match.overlayVersion + 1,
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

  /// Persists wizard progress (squads, roles, officials, rules, venue) on scheduled matches.
  Future<void> syncMatchSetupFromDraft({
    required String matchId,
    required MatchRulesModel rules,
    required LocationModel location,
    required String venue,
    required DateTime? scheduledAt,
    required String teamAName,
    required String teamBName,
    String? teamAId,
    String? teamBId,
    required MatchSetupData setup,
  }) async {
    final scorerIds = setup.scorers
        .map((s) => s.userId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();
    await _enqueueMatchPatch(matchId, {
      'title': '$teamAName vs $teamBName',
      if (teamAId != null) 'teamAId': teamAId,
      if (teamBId != null) 'teamBId': teamBId,
      'teamAName': teamAName,
      'teamBName': teamBName,
      'rules': rules.toMap(),
      'location': location.toMap(),
      'venue': venue,
      if (scheduledAt != null) 'scheduledAt': scheduledAt.toIso8601String(),
      ...setup.toMap(),
      if (scorerIds.isNotEmpty) 'scorerIds': scorerIds,
    });
  }

  Future<void> updateMatchSquad({
    required String matchId,
    required bool isTeamA,
    required List<MatchPlayerSnapshot> playing,
    required List<MatchPlayerSnapshot> substitutes,
  }) async {
    final match = await getMatch(matchId);
    if (match == null) throw StateError('Match not found');
    final playingKey =
        isTeamA ? 'teamAPlayingPlayers' : 'teamBPlayingPlayers';
    final subsKey =
        isTeamA ? 'teamASubstitutePlayers' : 'teamBSubstitutePlayers';
    final squadIdsKey = isTeamA ? 'teamASquadIds' : 'teamBSquadIds';
    await _enqueueMatchPatch(matchId, {
      playingKey: playing.map((p) => p.toMap()).toList(),
      subsKey: substitutes.map((p) => p.toMap()).toList(),
      squadIdsKey: playing.map((p) => p.id).toList(),
    });
  }

  Future<void> updateMatchRules(String matchId, MatchRulesModel rules) async {
    final match = await getMatch(matchId);
    if (match == null) throw StateError('Match not found');
    final updated = match.copyWith(rules: rules);
    await _enqueueMatchUpdate(updated);
  }

  Future<void> startMatchBreak({
    required String matchId,
    required String breakType,
    required String startedBy,
    String reason = '',
  }) async {
    final match = await getMatch(matchId);
    if (match == null) throw StateError('Match not found');
    if (match.isMatchBreakActive) {
      throw StateError('A break is already active');
    }
    final active = ActiveMatchBreakModel(
      breakType: breakType,
      startTime: DateTime.now(),
      startedBy: startedBy,
      reason: reason,
    );
    final updated = match.copyWith(activeMatchBreak: active);
    await _persistMatchLocally(updated);
    await _enqueueMatchPatch(matchId, {
      'activeMatchBreak': active.toMap(),
    });
  }

  Future<void> endMatchBreak(String matchId) async {
    final match = await getMatch(matchId);
    if (match == null) throw StateError('Match not found');
    final active = match.activeMatchBreak;
    if (active == null || !active.isActive) {
      throw StateError('No active break');
    }
    final end = DateTime.now();
    final duration = end.difference(active.startTime).inSeconds;
    final entry = MatchBreakHistoryEntry(
      breakType: active.breakType,
      startTime: active.startTime,
      endTime: end,
      durationSeconds: duration,
      reason: active.reason,
    );
    final history = [...match.matchBreakHistory, entry];
    final updated = match.copyWith(
      clearActiveMatchBreak: true,
      matchBreakHistory: history,
    );
    await _enqueueMatchUpdate(
      updated,
      fieldDeletes: const ['activeMatchBreak'],
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
