import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/cricket_math.dart';
import '../../data/models/innings_model.dart';
import '../../data/models/match_model.dart';

class ScoreboardCard extends StatelessWidget {
  const ScoreboardCard({
    super.key,
    required this.match,
    this.innings,
    this.isLive = false,
  });

  final MatchModel match;
  final InningsModel? innings;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final inn = innings ?? match.currentInnings;
    final rules = match.rules;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.scoreboardBg, Color(0xFF1565C0)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isLive) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.liveIndicator,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    match.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _teamScore(match.teamAName, inn, match.teamAId),
                const Text('vs',
                    style: TextStyle(color: AppColors.gold, fontSize: 18)),
                _teamScore(match.teamBName, inn, match.teamBId),
              ],
            ),
            if (inn != null) ...[
              const SizedBox(height: 12),
              Text(
                '${CricketMath.formatOvers(inn.legalBalls, rules.ballsPerOver)} ov • RR ${CricketMath.runRate(inn.totalRuns, inn.legalBalls, rules.ballsPerOver).toStringAsFixed(2)}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _teamScore(String name, InningsModel? inn, String? teamId) {
    final isBatting = inn != null && inn.battingTeamId == teamId;
    final score = isBatting ? '${inn.totalRuns}/${inn.totalWickets}' : '—';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name,
            style: TextStyle(
              color: isBatting ? AppColors.gold : Colors.white70,
              fontWeight: FontWeight.w600,
            )),
        Text(
          score,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
