import 'package:flutter/material.dart';
import 'package:crickflow/core/theme/app_dimens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/match_score_display.dart';
import '../../../core/utils/cricket_math.dart';
import '../../../data/models/match_model.dart';
import '../../../core/utils/deep_link_utils.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/scoreboard_card.dart';

class ScorecardScreen extends ConsumerWidget {
  const ScorecardScreen({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchAsync = ref.watch(matchProvider(matchId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scorecard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              matchAsync.whenData((match) {
                if (match != null) _shareScorecard(match);
              });
            },
          ),
        ],
      ),
      body: matchAsync.when(
        data: (match) {
          if (match == null) return const Center(child: Text('Not found'));
          final rules = match.rules;

          return ListView(
            children: [
              ScoreboardCard(
                match: match,
                innings: match.currentInnings,
                isLive: match.status == MatchStatus.live ||
                    match.status == MatchStatus.inningsBreak,
              ),
              ...match.innings.map((inn) {
                final batting = MatchScoreDisplay.battingTeamName(match, inn);
                final bowling = MatchScoreDisplay.bowlingTeamName(match, inn);
                final rr = MatchScoreDisplay.runRateFor(inn, rules);
                return Card(
                  margin: const EdgeInsets.all(AppDimens.spaceMd),
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimens.spaceMd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Innings ${inn.inningsNumber}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$batting vs $bowling',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        Text(
                          '${inn.totalRuns}/${inn.totalWickets} '
                          '(${CricketMath.formatOvers(inn.legalBalls, rules.ballsPerOver)} ov) · '
                          'RR ${rr.toStringAsFixed(2)}',
                          style: const TextStyle(color: AppColors.gold),
                        ),
                        const Divider(),
                        const Text('Batting',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        ...inn.batsmen.map((b) => ListTile(
                              dense: true,
                              title: Text(b.playerName.isNotEmpty
                                  ? b.playerName
                                  : b.playerId),
                              trailing: Text('${b.runs} (${b.balls})'),
                            )),
                        const Text('Bowling',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        ...inn.bowlers.map((b) => ListTile(
                              dense: true,
                              title: Text(b.playerName.isNotEmpty
                                  ? b.playerName
                                  : b.playerId),
                              trailing: Text(
                                '${CricketMath.formatOvers(b.oversBowledBalls, rules.ballsPerOver)}-${b.runsConceded}-${b.wickets}',
                              ),
                            )),
                      ],
                    ),
                  ),
                );
              }),
              if (match.resultSummary.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppDimens.spaceMd),
                  child: Text(
                    match.resultSummary,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  void _shareScorecard(MatchModel match) {
    final buffer = StringBuffer();
    buffer.writeln('${match.title} — CrickFlow');
    buffer.writeln('${match.teamAName} vs ${match.teamBName}');
    if (match.venue.isNotEmpty) buffer.writeln('Venue: ${match.venue}');
    buffer.writeln();

    for (final inn in match.innings) {
      buffer.writeln(
        'Innings ${inn.inningsNumber}: ${inn.totalRuns}/${inn.totalWickets}',
      );
    }

    if (match.resultSummary.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(match.resultSummary);
    }

    buffer.writeln();
    buffer.writeln('Live web: ${DeepLinkUtils.publicLiveScorecardUri(match.id)}');
    buffer.writeln('Open in app: ${DeepLinkUtils.scorecardUri(match.id)}');

    Share.share(buffer.toString());
  }
}
