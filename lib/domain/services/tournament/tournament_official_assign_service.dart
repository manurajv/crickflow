import '../../../core/constants/enums.dart';
import '../../../data/models/match_setup_draft_models.dart';
import '../../../data/models/tournament/tournament_official_model.dart';

/// Maps tournament roster officials into match setup slots for the start flow.
class TournamentOfficialAssignService {
  static const _umpireLabels = [
    'Umpire 1',
    'Umpire 2',
    'Third Umpire',
    '4th Umpire',
  ];
  static const _scorerLabels = ['Scorer 1', 'Scorer 2'];
  static const _commentatorLabels = ['Commentator 1', 'Commentator 2'];

  /// True when no match officials have been assigned yet.
  bool shouldAutoFill(MatchSetupData setup) {
    final hasOfficials = setup.umpires.any((e) => e.name.isNotEmpty) ||
        setup.scorers.any((e) => e.name.isNotEmpty) ||
        setup.commentators.any((e) => e.name.isNotEmpty) ||
        setup.liveStreamers.any((e) => e.name.isNotEmpty) ||
        (setup.referee?.name.isNotEmpty ?? false);
    return !hasOfficials;
  }

  MatchSetupData applyTournamentOfficials(
    MatchSetupData setup,
    List<TournamentOfficialModel> officials,
  ) {
    if (officials.isEmpty) return setup;

    final byRole = <TournamentOfficialRole, List<TournamentOfficialModel>>{};
    for (final official in officials) {
      byRole.putIfAbsent(official.role, () => []).add(official);
    }

    return setup.copyWith(
      umpires: _mergeCategory(
        existing: setup.umpires,
        incoming: _entriesForRole(
          byRole[TournamentOfficialRole.umpire] ?? const [],
          _umpireLabels,
        ),
      ),
      scorers: _mergeCategory(
        existing: setup.scorers,
        incoming: _entriesForRole(
          byRole[TournamentOfficialRole.scorer] ?? const [],
          _scorerLabels,
        ),
      ),
      commentators: _mergeCategory(
        existing: setup.commentators,
        incoming: _entriesForRole(
          byRole[TournamentOfficialRole.commentator] ?? const [],
          _commentatorLabels,
        ),
      ),
      liveStreamers: _mergeCategory(
        existing: setup.liveStreamers,
        incoming: _entriesForRole(
          byRole[TournamentOfficialRole.streamer] ?? const [],
          const ['Live streamer'],
        ),
      ),
    );
  }

  List<MatchOfficialEntry> _entriesForRole(
    List<TournamentOfficialModel> officials,
    List<String> slotLabels,
  ) {
    final entries = <MatchOfficialEntry>[];
    for (var i = 0; i < officials.length && i < slotLabels.length; i++) {
      final official = officials[i];
      entries.add(
        MatchOfficialEntry(
          userId: official.userId,
          name: official.displayName.isNotEmpty
              ? official.displayName
              : 'Official',
          slotLabel: slotLabels[i],
        ),
      );
    }
    return entries;
  }

  List<MatchOfficialEntry> _mergeCategory({
    required List<MatchOfficialEntry> existing,
    required List<MatchOfficialEntry> incoming,
  }) {
    if (incoming.isEmpty) return existing;
    if (existing.any((e) => e.name.isNotEmpty)) return existing;
    return incoming;
  }
}
