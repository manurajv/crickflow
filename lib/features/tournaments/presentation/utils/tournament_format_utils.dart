import '../../../../core/constants/enums.dart';
import '../../../../domain/services/auto_fixture_generator_service.dart';
import 'tournament_display_utils.dart';

/// Default auto-fixture mode when scheduling from a tournament's saved format.
AutoFixtureMode defaultAutoFixtureMode(TournamentFormat format) =>
    switch (format) {
      TournamentFormat.league => AutoFixtureMode.league,
      TournamentFormat.knockout => AutoFixtureMode.knockout,
      TournamentFormat.leagueKnockout => AutoFixtureMode.hybrid,
      TournamentFormat.custom => AutoFixtureMode.custom,
    };

/// Modes shown first in the auto-fixture picker (recommended for this format).
List<AutoFixtureMode> recommendedAutoFixtureModes(TournamentFormat format) =>
    switch (format) {
      TournamentFormat.league => [
          AutoFixtureMode.league,
          AutoFixtureMode.roundRobin,
          AutoFixtureMode.custom,
        ],
      TournamentFormat.knockout => [
          AutoFixtureMode.knockout,
          AutoFixtureMode.custom,
        ],
      TournamentFormat.leagueKnockout => [
          AutoFixtureMode.hybrid,
          AutoFixtureMode.groupStage,
          AutoFixtureMode.knockout,
          AutoFixtureMode.league,
        ],
      TournamentFormat.custom => AutoFixtureMode.values,
    };

/// Human-readable primary fixture action label for the Fixtures tab.
String primaryFixtureActionLabel(TournamentFormat format) =>
    switch (format) {
      TournamentFormat.league => 'Generate league fixtures',
      TournamentFormat.knockout => 'Generate knockout bracket',
      TournamentFormat.leagueKnockout => 'Generate group-stage fixtures',
      TournamentFormat.custom => 'Generate fixtures',
    };

String primaryFixtureActionDescription(TournamentFormat format) =>
    switch (format) {
      TournamentFormat.league =>
        'Round robin for all teams — matches your ${tournamentFormatLabel(format)} format.',
      TournamentFormat.knockout =>
        'Single-elimination bracket from current teams.',
      TournamentFormat.leagueKnockout =>
        'Round robin within each group. Create groups first, then seed knockout from standings.',
      TournamentFormat.custom =>
        'Uses league-style generation; schedule knockout or manual matches separately.',
    };

bool formatUsesGroupStage(TournamentFormat format) =>
    format == TournamentFormat.leagueKnockout;

bool formatUsesKnockoutBracket(TournamentFormat format) =>
    format == TournamentFormat.knockout ||
    format == TournamentFormat.leagueKnockout;

bool formatUsesPointsTable(TournamentFormat format) =>
    format != TournamentFormat.knockout;

/// Sort auto-fixture modes: recommended first, then the rest.
List<AutoFixtureMode> orderedAutoFixtureModes(TournamentFormat format) {
  final recommended = recommendedAutoFixtureModes(format);
  final rest =
      AutoFixtureMode.values.where((m) => !recommended.contains(m)).toList();
  return [...recommended, ...rest];
}
