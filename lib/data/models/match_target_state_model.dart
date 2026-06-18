import 'package:equatable/equatable.dart';

/// Target-revision metadata stored on the match document (scorer-assisted DLS).
class MatchTargetStateModel extends Equatable {
  const MatchTargetStateModel({
    this.revisionMethod,
    this.originalOvers,
    this.revisedOvers,
    this.revisedTarget,
    this.originalTarget,
    this.dlsApplied = false,
    this.pendingChaseTarget,
    this.considerAllOversForNrr = true,
    this.matchOutcome,
    this.abandonedReason,
    this.liveBannerMessage,
    this.liveBannerDismissed = false,
    // Legacy fields (read-only compat)
    this.targetRevisionMethod,
    this.dlsVersion,
    this.oversLostPerInnings,
    this.revisedTotalOvers,
  });

  /// `DLS` or `manual`.
  final String? revisionMethod;
  final int? originalOvers;
  final int? revisedOvers;
  final int? revisedTarget;
  /// Chase target before the latest revision (for match summary).
  final int? originalTarget;
  final bool dlsApplied;
  final int? pendingChaseTarget;
  final bool considerAllOversForNrr;
  final String? matchOutcome;
  final String? abandonedReason;
  final String? liveBannerMessage;
  final bool liveBannerDismissed;

  /// Legacy Firestore keys (read compat only).
  final String? targetRevisionMethod;
  final String? dlsVersion;
  final int? oversLostPerInnings;
  final int? revisedTotalOvers;

  int? get effectiveRevisedOvers => revisedOvers ?? revisedTotalOvers;

  int? get effectiveOriginalTarget =>
      originalTarget ?? pendingChaseTarget;

  int? get effectiveRevisedTarget =>
      revisedTarget ?? pendingChaseTarget;

  factory MatchTargetStateModel.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return const MatchTargetStateModel();
    return MatchTargetStateModel(
      revisionMethod: map['revisionMethod'] as String? ??
          map['targetRevisionMethod'] as String?,
      originalOvers: map['originalOvers'] as int?,
      revisedOvers: map['revisedOvers'] as int? ?? map['revisedTotalOvers'] as int?,
      revisedTarget: map['revisedTarget'] as int?,
      originalTarget: map['originalTarget'] as int?,
      dlsApplied: map['dlsApplied'] as bool? ?? false,
      pendingChaseTarget: map['pendingChaseTarget'] as int?,
      considerAllOversForNrr: map['considerAllOversForNrr'] as bool? ?? true,
      matchOutcome: map['matchOutcome'] as String?,
      abandonedReason: map['abandonedReason'] as String?,
      liveBannerMessage: map['liveBannerMessage'] as String?,
      liveBannerDismissed: map['liveBannerDismissed'] as bool? ?? false,
      targetRevisionMethod: map['targetRevisionMethod'] as String?,
      dlsVersion: map['dlsVersion'] as String?,
      oversLostPerInnings: map['oversLostPerInnings'] as int?,
      revisedTotalOvers: map['revisedTotalOvers'] as int?,
    );
  }

  Map<String, dynamic> toMap() => {
        if (revisionMethod != null) 'revisionMethod': revisionMethod,
        if (originalOvers != null) 'originalOvers': originalOvers,
        if (revisedOvers != null) 'revisedOvers': revisedOvers,
        if (revisedTarget != null) 'revisedTarget': revisedTarget,
        if (originalTarget != null) 'originalTarget': originalTarget,
        if (dlsApplied) 'dlsApplied': dlsApplied,
        if (pendingChaseTarget != null) 'pendingChaseTarget': pendingChaseTarget,
        'considerAllOversForNrr': considerAllOversForNrr,
        if (matchOutcome != null) 'matchOutcome': matchOutcome,
        if (abandonedReason != null && abandonedReason!.isNotEmpty)
          'abandonedReason': abandonedReason,
        if (liveBannerMessage != null && liveBannerMessage!.isNotEmpty)
          'liveBannerMessage': liveBannerMessage,
        if (liveBannerDismissed) 'liveBannerDismissed': liveBannerDismissed,
      };

  MatchTargetStateModel copyWith({
    String? revisionMethod,
    int? originalOvers,
    int? revisedOvers,
    int? revisedTarget,
    int? originalTarget,
    bool? dlsApplied,
    int? pendingChaseTarget,
    bool? considerAllOversForNrr,
    String? matchOutcome,
    String? abandonedReason,
    String? liveBannerMessage,
    bool? liveBannerDismissed,
    bool clearMatchOutcome = false,
  }) {
    return MatchTargetStateModel(
      revisionMethod: revisionMethod ?? this.revisionMethod,
      originalOvers: originalOvers ?? this.originalOvers,
      revisedOvers: revisedOvers ?? this.revisedOvers,
      revisedTarget: revisedTarget ?? this.revisedTarget,
      originalTarget: originalTarget ?? this.originalTarget,
      dlsApplied: dlsApplied ?? this.dlsApplied,
      pendingChaseTarget: pendingChaseTarget ?? this.pendingChaseTarget,
      considerAllOversForNrr:
          considerAllOversForNrr ?? this.considerAllOversForNrr,
      matchOutcome:
          clearMatchOutcome ? null : (matchOutcome ?? this.matchOutcome),
      abandonedReason: abandonedReason ?? this.abandonedReason,
      liveBannerMessage: liveBannerMessage ?? this.liveBannerMessage,
      liveBannerDismissed: liveBannerDismissed ?? this.liveBannerDismissed,
    );
  }

  @override
  List<Object?> get props => [dlsApplied, revisedTarget, pendingChaseTarget];
}
