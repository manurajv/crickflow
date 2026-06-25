import 'package:equatable/equatable.dart';

import '../../../domain/services/tournament/tournament_analytics_models.dart';

/// Cached tournament analytics persisted in Firestore.
class TournamentAnalyticsDoc extends Equatable {
  const TournamentAnalyticsDoc({
    required this.tournamentId,
    this.updatedAt,
    this.matchCount = 0,
    this.scoredMatchCount = 0,
    this.scopeLabel = 'Entire tournament',
    this.summaryMetrics = const {},
    this.version = 1,
  });

  final String tournamentId;
  final DateTime? updatedAt;
  final int matchCount;
  final int scoredMatchCount;
  final String scopeLabel;
  final Map<String, String> summaryMetrics;
  final int version;

  factory TournamentAnalyticsDoc.fromMap(String id, Map<String, dynamic> map) {
    return TournamentAnalyticsDoc(
      tournamentId: id,
      updatedAt: _readDate(map['updatedAt']),
      matchCount: map['matchCount'] as int? ?? 0,
      scoredMatchCount: map['scoredMatchCount'] as int? ?? 0,
      scopeLabel: map['scopeLabel'] as String? ?? 'Entire tournament',
      summaryMetrics: Map<String, String>.from(
        (map['summaryMetrics'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            ) ??
            {},
      ),
      version: map['version'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toMap() => {
        'tournamentId': tournamentId,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
        'matchCount': matchCount,
        'scoredMatchCount': scoredMatchCount,
        'scopeLabel': scopeLabel,
        'summaryMetrics': summaryMetrics,
        'version': version,
      };

  static TournamentAnalyticsDoc fromSnapshot(
    String tournamentId,
    TournamentAnalyticsSnapshot snapshot,
  ) {
    final metrics = <String, String>{};
    for (final m in snapshot.summary.metrics.take(20)) {
      metrics[m.label] = m.value;
    }
    return TournamentAnalyticsDoc(
      tournamentId: tournamentId,
      updatedAt: snapshot.updatedAt ?? DateTime.now(),
      matchCount: snapshot.matchCount,
      scoredMatchCount: snapshot.scoredMatchCount,
      scopeLabel: snapshot.filter.scopeLabel,
      summaryMetrics: metrics,
    );
  }

  static DateTime? _readDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString());
  }

  @override
  List<Object?> get props =>
      [tournamentId, matchCount, scoredMatchCount, updatedAt];
}
