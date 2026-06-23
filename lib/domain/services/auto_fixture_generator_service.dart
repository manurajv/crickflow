import '../../core/constants/enums.dart';
import '../../data/repositories/tournament_repository.dart';

/// Routes auto-fixture generation by tournament format.
class AutoFixtureGeneratorService {
  const AutoFixtureGeneratorService();

  Future<List<String>> generate({
    required TournamentRepository repository,
    required String tournamentId,
    required String createdBy,
    required TournamentFormat format,
    String? roundId,
    String? roundName,
  }) async {
    switch (format) {
      case TournamentFormat.league:
        return repository.generateLeagueFixtures(
          tournamentId: tournamentId,
          createdBy: createdBy,
          roundId: roundId,
          roundName: roundName,
        );
      case TournamentFormat.knockout:
        return repository.generateKnockoutBracket(
          tournamentId: tournamentId,
          createdBy: createdBy,
          roundId: roundId,
          roundName: roundName,
        );
      case TournamentFormat.leagueKnockout:
        final groupIds = await repository.generateGroupStageFixtures(
          tournamentId: tournamentId,
          createdBy: createdBy,
          roundId: roundId,
          roundName: roundName ?? 'Group Stage',
        );
        if (groupIds.isEmpty) {
          return repository.generateLeagueFixtures(
            tournamentId: tournamentId,
            createdBy: createdBy,
            roundId: roundId,
            roundName: roundName,
          );
        }
        return groupIds;
      case TournamentFormat.custom:
        return repository.generateLeagueFixtures(
          tournamentId: tournamentId,
          createdBy: createdBy,
          roundId: roundId,
          roundName: roundName,
        );
    }
  }

  /// UI-facing fixture modes mapped to repository calls.
  Future<List<String>> generateByMode({
    required TournamentRepository repository,
    required String tournamentId,
    required String createdBy,
    required AutoFixtureMode mode,
    String? roundId,
    String? roundName,
  }) {
    return switch (mode) {
      AutoFixtureMode.league ||
      AutoFixtureMode.roundRobin =>
        repository.generateLeagueFixtures(
          tournamentId: tournamentId,
          createdBy: createdBy,
          roundId: roundId,
          roundName: roundName,
        ),
      AutoFixtureMode.groupStage => repository.generateGroupStageFixtures(
          tournamentId: tournamentId,
          createdBy: createdBy,
          roundId: roundId,
          roundName: roundName,
        ),
      AutoFixtureMode.knockout => repository.generateKnockoutBracket(
          tournamentId: tournamentId,
          createdBy: createdBy,
          roundId: roundId,
          roundName: roundName,
        ),
      AutoFixtureMode.hybrid => generate(
          repository: repository,
          tournamentId: tournamentId,
          createdBy: createdBy,
          format: TournamentFormat.leagueKnockout,
          roundId: roundId,
          roundName: roundName,
        ),
      AutoFixtureMode.custom => repository.generateLeagueFixtures(
          tournamentId: tournamentId,
          createdBy: createdBy,
          roundId: roundId,
          roundName: roundName,
        ),
    };
  }
}

enum AutoFixtureMode {
  league,
  roundRobin,
  groupStage,
  knockout,
  hybrid,
  custom,
}

extension AutoFixtureModeX on AutoFixtureMode {
  String get label => switch (this) {
        AutoFixtureMode.league => 'League',
        AutoFixtureMode.roundRobin => 'Round Robin',
        AutoFixtureMode.groupStage => 'Group Stage',
        AutoFixtureMode.knockout => 'Knockout',
        AutoFixtureMode.hybrid => 'Hybrid (Groups + Knockout)',
        AutoFixtureMode.custom => 'Custom',
      };

  String get description => switch (this) {
        AutoFixtureMode.league =>
          'Every team plays each other once across the tournament.',
        AutoFixtureMode.roundRobin =>
          'Full round robin — all teams face every other team.',
        AutoFixtureMode.groupStage =>
          'Fixtures within each group only (requires groups).',
        AutoFixtureMode.knockout =>
          'Single-elimination bracket from current teams.',
        AutoFixtureMode.hybrid =>
          'Group-stage fixtures, then knockout when groups are ready.',
        AutoFixtureMode.custom =>
          'Uses your tournament default rules for league fixtures.',
      };
}
