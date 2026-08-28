import 'package:flutter_test/flutter_test.dart';

import 'package:crickflow/features/tournaments/presentation/tournament_dashboard_sections.dart';

void main() {
  test('Summary tab is hidden until the tournament is completed', () {
    final active = TournamentDashboardSection.tabOrderForStatus(false);
    final completed = TournamentDashboardSection.tabOrderForStatus(true);

    expect(active, isNot(contains(TournamentDashboardSection.summary)));
    expect(completed, contains(TournamentDashboardSection.summary));
    expect(completed.length, active.length + 1);
    expect(
      completed.take(2).toList(),
      [
        TournamentDashboardSection.overview,
        TournamentDashboardSection.summary,
      ],
    );
  });

  test('completed tournaments land on Summary from the default Overview route', () {
    expect(
      TournamentDashboardSection.landingSection(
        isCompleted: true,
        requested: TournamentDashboardSection.overview,
      ),
      TournamentDashboardSection.summary,
    );
    expect(
      TournamentDashboardSection.landingSection(
        isCompleted: true,
        requested: TournamentDashboardSection.matches,
      ),
      TournamentDashboardSection.matches,
    );
    expect(
      TournamentDashboardSection.landingSection(
        isCompleted: false,
        requested: TournamentDashboardSection.overview,
      ),
      TournamentDashboardSection.overview,
    );
    expect(
      TournamentDashboardSection.landingSection(
        isCompleted: false,
        requested: TournamentDashboardSection.summary,
      ),
      TournamentDashboardSection.overview,
    );
  });

  test('indexOfSection respects completion status', () {
    expect(
      TournamentDashboardSection.indexOfSection(
        TournamentDashboardSection.matches,
        isCompleted: false,
      ),
      1,
    );
    expect(
      TournamentDashboardSection.indexOfSection(
        TournamentDashboardSection.matches,
        isCompleted: true,
      ),
      2,
    );
  });
}
