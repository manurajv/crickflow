import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/enums.dart';
import '../../data/models/innings_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/match_revision_model.dart';
import '../../data/models/match_timeline_event_model.dart';
import '../../domain/scoring/innings_completion_policy.dart';

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
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _uuid = const Uuid();

  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  DocumentReference<Map<String, dynamic>> _matchDoc(String matchId) =>
      _firestore.collection(AppConstants.matchesCollection).doc(matchId);

  CollectionReference<Map<String, dynamic>> _revisions(String matchId) =>
      _matchDoc(matchId).collection('matchRevisions');

  CollectionReference<Map<String, dynamic>> _timeline(String matchId) =>
      _matchDoc(matchId).collection('matchTimeline');

  Future<MatchModel?> getMatch(String matchId) async {
    final doc = await _matchDoc(matchId).get();
    if (!doc.exists) return null;
    return MatchModel.fromMap(matchId, doc.data()!);
  }

  Future<void> dismissLiveBanner(String matchId) async {
    final match = await getMatch(matchId);
    if (match == null) return;
    final updated = match.copyWith(
      targetState: match.targetState.copyWith(liveBannerDismissed: true),
    );
    await _matchDoc(matchId).update(updated.toMap());
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

    final batch = _firestore.batch();
    batch.update(_matchDoc(matchId), updated.toMap());

    if (penaltyRuns != 0) {
      final rev = MatchRevisionModel(
        id: _uuid.v4(),
        type: penaltyRuns > 0 ? 'penalty_added' : 'penalty_removed',
        penaltyRuns: penaltyRuns,
        reason: penaltyReason,
        createdBy: userId,
      );
      batch.set(_revisions(matchId).doc(rev.id), rev.toMap());
    }

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
    batch.set(_timeline(matchId).doc(timeline.id), timeline.toMap());

    if (penaltyRuns != 0) {
      final penaltyTimeline = MatchTimelineEventModel(
        id: _uuid.v4(),
        title: penaltyRuns > 0
            ? 'Penalty Runs Added'
            : 'Penalty Runs Removed',
        subtitle: '$penaltyRuns runs — $penaltyReason',
        createdBy: userId,
      );
      batch.set(
        _timeline(matchId).doc(penaltyTimeline.id),
        penaltyTimeline.toMap(),
      );
    }

    await batch.commit();
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

    final batch = _firestore.batch();
    batch.update(_matchDoc(matchId), updated.toMap());

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
    batch.set(_timeline(matchId).doc(timeline.id), timeline.toMap());

    await batch.commit();
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
    final batch = _firestore.batch();
    batch.update(_matchDoc(matchId), match.toMap());
    batch.set(_revisions(matchId).doc(revision.id), revision.toMap());
    final timeline = MatchTimelineEventModel(
      id: _uuid.v4(),
      title: timelineTitle,
      subtitle: timelineSubtitle,
      createdBy: userId,
    );
    batch.set(_timeline(matchId).doc(timeline.id), timeline.toMap());
    await batch.commit();
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
