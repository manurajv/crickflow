import 'package:flutter_test/flutter_test.dart';

import 'package:crickflow/features/tournaments/presentation/tournament_dashboard_sections.dart';

void main() {
  test('dashboard tab order keeps Summary in the first two tabs', () {
    expect(
      TournamentDashboardSection.tabOrder.take(2).toList(),
      [
        TournamentDashboardSection.overview,
        TournamentDashboardSection.summary,
      ],
    );
    expect(
      TournamentDashboardSection.tabOrderForStatus(false).length,
      TournamentDashboardSection.tabOrderForStatus(true).length,
    );
    expect(
      TournamentDashboardSection.indexOfSection(
        TournamentDashboardSection.summary,
      ),
      1,
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
  });
}
