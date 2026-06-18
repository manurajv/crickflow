import '../../data/models/match_model.dart';
import '../../data/models/match_setup_draft_models.dart';

/// Assigned scorer user IDs from match setup snapshots (not live player data).
List<String> assignedScorerUserIds(MatchModel match) {
  final ids = <String>[];
  void add(String? id) {
    if (id != null && id.isNotEmpty && !ids.contains(id)) ids.add(id);
  }

  add(match.scorer1UserId);
  add(match.scorer2UserId);

  final scorers = match.setup?.scorers ?? const <MatchOfficialEntry>[];
  for (final scorer in scorers) {
    add(scorer.userId);
  }

  for (final id in match.scorerIds) {
    add(id);
  }

  if (ids.isEmpty) {
    add(match.createdBy);
  }
  return ids;
}

bool isAssignedMatchScorer({
  required MatchModel match,
  required String? userId,
}) {
  if (userId == null || userId.isEmpty) return false;
  return assignedScorerUserIds(match).contains(userId);
}

MatchOfficialEntry? assignedScorerEntry(MatchModel match, int index) {
  final scorers = match.setup?.scorers ?? const <MatchOfficialEntry>[];
  if (index >= scorers.length) return null;
  final entry = scorers[index];
  if (entry.name.isEmpty) return null;
  return entry;
}
