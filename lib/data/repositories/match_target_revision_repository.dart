import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/enums.dart';
import '../../data/models/innings_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/match_revision_model.dart';
import '../../data/models/match_timeline_event_model.dart';
import '../../domain/scoring/innings_completion_policy.dart';
import '../local/match_local_store.dart';
import '../local/pending_sync_action.dart';
import '../services/offline_sync_service.dart';

/// Input for scorer-assisted DLS (official target entered manually).
class ScorerDlsRevisionInput {
  const ScorerDlsRevisionInput({
    required this.originalOvers,
    required this.revisedOvers,
    this.revisedTarget,
    this.reason = '',
    this.continueInnings = true,
  });

  final int originalOvers;
  final int revisedOvers;
  /// Required when ending innings; omitted when only reducing overs.
  final int? revisedTarget;
  final String reason;
  /// First innings only — `false` means scorer will end innings next.
  final bool continueInnings;
}

/// Persists target revisions, end-innings options, and match results.
class MatchTargetRevisionRepository {
  MatchTargetRevisionRepository({
    FirebaseFirestore? firestore,
    MatchLocalStore? localStore,
    OfflineSyncService? syncService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _localStore = localStore,
        _syncService = syncService,
        _uuid = const Uuid();

  final FirebaseFirestore _firestore;
  final MatchLocalStore? _localStore;
  final OfflineSyncService? _syncService;
  final Uuid _uuid;

  bool get _offlineEnabled => _localStore != null && _syncService != null;

  DocumentReference<Map<String, dynamic>> _matchDoc(String matchId) =>
      _firestore.collection(AppConstants.matchesCollection).doc(matchId);

  CollectionReference<Map<String, dynamic>> _revisions(String matchId) =>
      _matchDoc(matchId).collection('matchRevisions');

  CollectionReference<Map<String, dynamic>> _timeline(String matchId) =>
      _matchDoc(matchId).collection('matchTimeline');

  Future<MatchModel?> getMatch(String matchId) async {
    final local = _localStore;
    if (local != null) {
      final cached = await local.getMatch(matchId);
      if (cached != null) return cached;
    }
    final doc = await _matchDoc(matchId).get();
    if (!doc.exists) return null;
    return MatchModel.fromMap(matchId, doc.data()!);
  }

  Future<void> _persistLocally(MatchModel match) async {
    await _localStore?.saveSnapshot(matchId: match.id, match: match);
  }

  Future<void> _queueBatch({
    required String matchId,
    required MatchModel match,
    required List<FirestoreBatchOp> operations,
  }) async {
    await _persistLocally(match);
    final sync = _syncService;
    if (sync == null) {
      final batch = _firestore.batch();
      for (final op in operations) {
        var ref = _firestore.collection(op.collection).doc(op.docId);
        if (op.subcollection != null && op.subDocId != null) {
          ref = ref.collection(op.subcollection!).doc(op.subDocId!);
        }
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

  Stream<List<MatchRevisionModel>> watchMatchRevisions(String matchId) {
    return _revisions(matchId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => MatchRevisionModel.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<List<MatchRevisionModel>> fetchMatchRevisions(String matchId) async {
    final snap = await _revisions(matchId)
        .orderBy('createdAt', descending: false)
        .get();
    return snap.docs
        .map((d) => MatchRevisionModel.fromMap(d.id, d.data()))
        .toList();
  }

  Future<void> dismissLiveBanner(String matchId) async {
    final match = await getMatch(matchId);
    if (match == null) return;
    final updated = match.copyWith(
      targetState: match.targetState.copyWith(liveBannerDismissed: true),
    );
    await _persistLocally(updated);
    if (_offlineEnabled) {
      await _syncService!.enqueue(
        _syncService!.newAction(
          matchId: matchId,
          type: SyncActionType.matchUpdate,
          payload: {'matchData': updated.toMap()},
        ),
      );
    } else {
      await _matchDoc(matchId).update(updated.toMap());
    }
  }

  int _currentTarget(MatchModel match, InningsModel inn) {
    if (inn.inningsNumber >= 2 && !inn.isSuperOver) {
      return InningsCompletionPolicy.chaseTarget(match, inn);
    }
    return match.targetState.pendingChaseTarget ??
        match.targetState.revisedTarget ??
        inn.totalRuns + 1;
  }

  void _validateOversReduction(int originalOvers, int revisedOvers) {
    if (originalOvers <= 0 || revisedOvers <= 0) {
      throw ArgumentError('Overs must be greater than zero');
    }
    if (revisedOvers >= originalOvers) {
      throw ArgumentError('Reduced overs must be less than original overs');
    }
  }

  /// Scorer enters revised target from officials — no automatic calculation.
  Future<MatchModel> applyScorerDlsRevision({
    required String matchId,
    required ScorerDlsRevisionInput input,
    required String userId,
  }) async {
    final match = await getMatch(matchId);
    if (match == null) throw StateError('Match not found');
    final inn = match.currentInnings;
    if (inn == null) throw StateError('No active innings');
    final isSecondInnings = inn.inningsNumber >= 2 && !inn.isSuperOver;
    if (isSecondInnings) {
      if (input.revisedTarget == null || input.revisedTarget! <= 0) {
        throw ArgumentError('Enter a valid target');
      }
    } else if (!input.continueInnings &&
        (input.revisedTarget == null || input.revisedTarget! <= 0)) {
      throw ArgumentError('Enter the revised target from officials');
    }

    _validateOversReduction(input.originalOvers, input.revisedOvers);

    final oldTarget = _currentTarget(match, inn);
    final originalTarget = match.targetState.originalTarget ?? oldTarget;
    final oversOnly = !isSecondInnings && input.continueInnings;

    final banner = oversOnly
        ? 'Overs reduced to ${input.revisedOvers}'
        : isSecondInnings
            ? 'Overs ${input.revisedOvers} · Target ${input.revisedTarget}'
            : 'DLS Target Applied';

    var targetState = match.targetState.copyWith(
      revisionMethod: 'DLS',
      originalOvers: match.targetState.originalOvers ?? input.originalOvers,
      revisedOvers: input.revisedOvers,
      dlsApplied: !oversOnly,
      liveBannerMessage: banner,
      liveBannerDismissed: false,
    );

    if (!oversOnly && input.revisedTarget != null) {
      targetState = targetState.copyWith(
        revisedTarget: input.revisedTarget,
        originalTarget: originalTarget,
        pendingChaseTarget: input.revisedTarget,
        dlsApplied: true,
      );
    }

    final updatedRules =
        match.rules.copyWith(totalOvers: input.revisedOvers);

    var inningsList = List<InningsModel>.from(match.innings);
    if (isSecondInnings && input.revisedTarget != null) {
      final idx = match.currentInningsIndex;
      inningsList[idx] =
          _inningsWithTarget(inningsList[idx], input.revisedTarget!);
    }

    final updated = match.copyWith(
      rules: updatedRules,
      innings: inningsList,
      targetState: targetState,
      overlayVersion: match.overlayVersion + 1,
    );

    final timelineSubtitle = input.reason.isNotEmpty
        ? input.reason
        : oversOnly
            ? '${input.originalOvers} → ${input.revisedOvers} overs'
            : '${input.originalOvers} → ${input.revisedOvers} overs, target ${input.revisedTarget}';

    await _persistRevision(
      matchId: matchId,
      match: updated,
      revision: MatchRevisionModel(
        id: _uuid.v4(),
        type: 'DLS',
        revisionMethod: 'DLS',
        originalOvers: input.originalOvers,
        revisedOvers: input.revisedOvers,
        oldTarget: oversOnly ? null : oldTarget,
        newTarget: input.revisedTarget,
        reason: input.reason,
        createdBy: userId,
      ),
      timelineTitle: oversOnly ? 'Overs Reduced (DLS)' : 'Target Revised (DLS)',
      timelineSubtitle: timelineSubtitle,
      userId: userId,
    );

    return updated;
  }

  Future<MatchModel> applyManualTargetRevision({
    required String matchId,
    required int revisedTarget,
    required String reason,
    required String userId,
  }) async {
    final match = await getMatch(matchId);
    if (match == null) throw StateError('Match not found');
    final inn = match.currentInnings;
    if (inn == null) throw StateError('No active innings');
    if (revisedTarget <= 0) throw ArgumentError('Invalid target');

    final oldTarget = _currentTarget(match, inn);
    final originalTarget = match.targetState.originalTarget ?? oldTarget;

    var targetState = match.targetState.copyWith(
      revisionMethod: 'manual',
      revisedTarget: revisedTarget,
      originalTarget: originalTarget,
      pendingChaseTarget: revisedTarget,
      liveBannerMessage: reason.isNotEmpty
          ? 'Target Revised By Officials'
          : 'Target Revised: $revisedTarget',
      liveBannerDismissed: false,
    );

    final inningsList = List<InningsModel>.from(match.innings);
    if (inn.inningsNumber >= 2 && !inn.isSuperOver) {
      final idx = match.currentInningsIndex;
      inningsList[idx] = _inningsWithTarget(inningsList[idx], revisedTarget);
    }

    final updated = match.copyWith(
      innings: inningsList,
      targetState: targetState,
      overlayVersion: match.overlayVersion + 1,
    );

    await _persistRevision(
      matchId: matchId,
      match: updated,
      revision: MatchRevisionModel(
        id: _uuid.v4(),
        type: 'manual',
        revisionMethod: 'manual',
        oldTarget: oldTarget,
        newTarget: revisedTarget,
        reason: reason,
        createdBy: userId,
      ),
      timelineTitle: 'Target Revised (Manual)',
      timelineSubtitle:
          reason.isNotEmpty ? reason : 'New target: $revisedTarget',
      userId: userId,
    );

    return updated;
  }

  Future<MatchModel> endInningsWithReason({
    required String matchId,
    required String endReason,
    required bool considerAllOversForNrr,
    int penaltyRuns = 0,
    String penaltyReason = '',
    required String userId,
  }) async {
    final match = await getMatch(matchId);
    if (match == null) throw StateError('Match not found');
    final idx = match.currentInningsIndex;
    final inn = match.currentInnings;
    if (inn == null) throw StateError('No active innings');

    if (endReason == 'penalty' &&
        penaltyRuns != 0 &&
        penaltyReason.trim().isEmpty) {
      throw ArgumentError('Penalty reason is required');
    }

    final inningsList = List<InningsModel>.from(match.innings);
    final newRuns = inn.totalRuns + penaltyRuns;

    inningsList[idx] = InningsModel(
      inningsNumber: inn.inningsNumber,
      battingTeamId: inn.battingTeamId,
      bowlingTeamId: inn.bowlingTeamId,
      status: InningsStatus.completed,
      totalRuns: newRuns,
      totalWickets: inn.totalWickets,
      legalBalls: inn.legalBalls,
      extras: inn.extras,
      strikerId: inn.strikerId,
      nonStrikerId: inn.nonStrikerId,
      currentBowlerId: inn.currentBowlerId,
      currentWicketKeeperId: inn.currentWicketKeeperId,
      currentWicketKeeperName: inn.currentWicketKeeperName,
      batsmen: inn.batsmen,
      bowlers: inn.bowlers,
      partnershipRuns: inn.partnershipRuns,
      partnershipBalls: inn.partnershipBalls,
      isFreeHitActive: false,
      targetRuns: inn.targetRuns,
      isSuperOver: inn.isSuperOver,
      currentOverStartLegalBalls: inn.currentOverStartLegalBalls,
      currentOverNumber: inn.currentOverNumber,
      currentOverSegment: inn.currentOverSegment,
      currentSegmentStartLegalBalls: inn.currentSegmentStartLegalBalls,
      endReason: endReason,
      penaltyRuns: penaltyRuns,
      penaltyReason: penaltyReason,
      considerAllOversForNrr: considerAllOversForNrr,
    );

    final chaseTarget =
        match.targetState.pendingChaseTarget ?? newRuns + 1;

    var targetState = match.targetState.copyWith(
      considerAllOversForNrr: considerAllOversForNrr,
      pendingChaseTarget: chaseTarget,
    );

    if (penaltyRuns != 0) {
      final sign = penaltyRuns > 0 ? '+' : '';
      targetState = targetState.copyWith(
        liveBannerMessage: 'Penalty Applied: $sign$penaltyRuns Runs',
        liveBannerDismissed: false,
      );
    }

    final updated = match.copyWith(
      innings: inningsList,
      status: MatchStatus.inningsBreak,
      targetState: targetState,
      overlayVersion: match.overlayVersion + 1,
    );

    final timelineTitle = switch (endReason) {
      'declared' => 'Innings Declared',
      'all_out' => 'Innings Ended (All Out)',
      _ => 'Innings Ended',
    };
    final timeline = MatchTimelineEventModel(
      id: _uuid.v4(),
      title: timelineTitle,
      subtitle: penaltyRuns != 0 ? 'Penalty: $penaltyRuns' : '',
      createdBy: userId,
    );
    MatchTimelineEventModel? penaltyTimeline;
    MatchRevisionModel? penaltyRevision;
    if (penaltyRuns != 0) {
      penaltyRevision = MatchRevisionModel(
        id: _uuid.v4(),
        type: penaltyRuns > 0 ? 'penalty_added' : 'penalty_removed',
        penaltyRuns: penaltyRuns,
        reason: penaltyReason,
        createdBy: userId,
      );
      penaltyTimeline = MatchTimelineEventModel(
        id: _uuid.v4(),
        title: penaltyRuns > 0
            ? 'Penalty Runs Added'
            : 'Penalty Runs Removed',
        subtitle: '$penaltyRuns runs — $penaltyReason',
        createdBy: userId,
      );
    }

    if (_offlineEnabled) {
      final operations = <FirestoreBatchOp>[
        FirestoreBatchOp(
          op: 'update',
          collection: AppConstants.matchesCollection,
          docId: matchId,
          data: updated.toMap(),
        ),
        FirestoreBatchOp(
          op: 'set',
          collection: AppConstants.matchesCollection,
          docId: matchId,
          subcollection: 'matchTimeline',
          subDocId: timeline.id,
          data: timeline.toMap(),
        ),
      ];
      if (penaltyRevision != null) {
        operations.add(
          FirestoreBatchOp(
            op: 'set',
            collection: AppConstants.matchesCollection,
            docId: matchId,
            subcollection: 'matchRevisions',
            subDocId: penaltyRevision.id,
            data: penaltyRevision.toMap(),
          ),
        );
      }
      if (penaltyTimeline != null) {
        operations.add(
          FirestoreBatchOp(
            op: 'set',
            collection: AppConstants.matchesCollection,
            docId: matchId,
            subcollection: 'matchTimeline',
            subDocId: penaltyTimeline.id,
            data: penaltyTimeline.toMap(),
          ),
        );
      }
      await _queueBatch(
        matchId: matchId,
        match: updated,
        operations: operations,
      );
    } else {
      final batch = _firestore.batch();
      batch.update(_matchDoc(matchId), updated.toMap());
      if (penaltyRevision != null) {
        batch.set(_revisions(matchId).doc(penaltyRevision.id), penaltyRevision.toMap());
      }
      batch.set(_timeline(matchId).doc(timeline.id), timeline.toMap());
      if (penaltyTimeline != null) {
        batch.set(
          _timeline(matchId).doc(penaltyTimeline.id),
          penaltyTimeline.toMap(),
        );
      }
      await batch.commit();
    }
    return updated;
  }

  Future<MatchModel> setMatchResult({
    required String matchId,
    String? winnerTeamId,
    bool isDraw = false,
    bool isAbandoned = false,
    String abandonedReason = '',
    required bool considerAllOversForNrr,
    required String userId,
  }) async {
    final match = await getMatch(matchId);
    if (match == null) throw StateError('Match not found');

    if (isAbandoned && abandonedReason.trim().isEmpty) {
      throw ArgumentError('Abandoned reason is required');
    }

    var targetState = match.targetState.copyWith(
      considerAllOversForNrr: considerAllOversForNrr,
    );

    String resultSummary;
    MatchStatus status = MatchStatus.completed;
    String? winner;

    if (isAbandoned) {
      status = MatchStatus.abandoned;
      targetState = targetState.copyWith(
        matchOutcome: 'abandoned',
        abandonedReason: abandonedReason,
      );
      resultSummary = 'Match abandoned — $abandonedReason';
      winner = null;
    } else if (isDraw) {
      targetState = targetState.copyWith(matchOutcome: 'draw');
      resultSummary = 'Match drawn';
      winner = null;
    } else {
      winner = winnerTeamId;
      final teamName = winner == match.teamAId
          ? match.teamAName
          : winner == match.teamBId
              ? match.teamBName
              : 'Winner';
      resultSummary = '$teamName won';
    }

    final updated = match.copyWith(
      status: status,
      completedAt: DateTime.now(),
      winnerTeamId: winner,
      resultSummary: resultSummary,
      targetState: targetState,
      overlayVersion: match.overlayVersion + 1,
    );

    final timelineTitle = isAbandoned
        ? 'Match Abandoned'
        : isDraw
            ? 'Match Drawn'
            : 'Match Result';
    final timeline = MatchTimelineEventModel(
      id: _uuid.v4(),
      title: timelineTitle,
      subtitle: resultSummary,
      createdBy: userId,
    );

    if (_offlineEnabled) {
      await _queueBatch(
        matchId: matchId,
        match: updated,
        operations: [
          FirestoreBatchOp(
            op: 'update',
            collection: AppConstants.matchesCollection,
            docId: matchId,
            data: updated.toMap(),
          ),
          FirestoreBatchOp(
            op: 'set',
            collection: AppConstants.matchesCollection,
            docId: matchId,
            subcollection: 'matchTimeline',
            subDocId: timeline.id,
            data: timeline.toMap(),
          ),
        ],
      );
    } else {
      final batch = _firestore.batch();
      batch.update(_matchDoc(matchId), updated.toMap());
      batch.set(_timeline(matchId).doc(timeline.id), timeline.toMap());
      await batch.commit();
    }
    return updated;
  }

  Future<void> _persistRevision({
    required String matchId,
    required MatchModel match,
    required MatchRevisionModel revision,
    required String timelineTitle,
    required String timelineSubtitle,
    required String userId,
  }) async {
    final timeline = MatchTimelineEventModel(
      id: _uuid.v4(),
      title: timelineTitle,
      subtitle: timelineSubtitle,
      createdBy: userId,
    );
    await _queueBatch(
      matchId: matchId,
      match: match,
      operations: [
        FirestoreBatchOp(
          op: 'update',
          collection: AppConstants.matchesCollection,
          docId: matchId,
          data: match.toMap(),
        ),
        FirestoreBatchOp(
          op: 'set',
          collection: AppConstants.matchesCollection,
          docId: matchId,
          subcollection: 'matchRevisions',
          subDocId: revision.id,
          data: revision.toMap(),
        ),
        FirestoreBatchOp(
          op: 'set',
          collection: AppConstants.matchesCollection,
          docId: matchId,
          subcollection: 'matchTimeline',
          subDocId: timeline.id,
          data: timeline.toMap(),
        ),
      ],
    );
  }

  InningsModel _inningsWithTarget(InningsModel cur, int target) {
    return InningsModel(
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
      currentWicketKeeperId: cur.currentWicketKeeperId,
      currentWicketKeeperName: cur.currentWicketKeeperName,
      batsmen: cur.batsmen,
      bowlers: cur.bowlers,
      partnershipRuns: cur.partnershipRuns,
      partnershipBalls: cur.partnershipBalls,
      isFreeHitActive: cur.isFreeHitActive,
      targetRuns: target,
      isSuperOver: cur.isSuperOver,
      currentOverStartLegalBalls: cur.currentOverStartLegalBalls,
      currentOverNumber: cur.currentOverNumber,
      currentOverSegment: cur.currentOverSegment,
      currentSegmentStartLegalBalls: cur.currentSegmentStartLegalBalls,
      endReason: cur.endReason,
      penaltyRuns: cur.penaltyRuns,
      penaltyReason: cur.penaltyReason,
      considerAllOversForNrr: cur.considerAllOversForNrr,
    );
  }
}
