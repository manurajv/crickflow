import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/cricket_math.dart';
import '../../../../data/models/innings_model.dart';
import '../../../../data/models/lineup_player.dart';
import '../../../../data/models/match_model.dart';

class SelectBowlerSheet extends StatelessWidget {
  const SelectBowlerSheet({
    super.key,
    required this.match,
    required this.innings,
    required this.bowlingSquad,
    required this.overNumber,
    required this.onSelected,
    required this.ballsPerOver,
    this.excludedBowlerIds = const {},
    this.wicketKeeperId,
  });

  final MatchModel match;
  final InningsModel innings;
  final List<LineupPlayer> bowlingSquad;
  final int overNumber;
  final int ballsPerOver;
  final Set<String> excludedBowlerIds;
  final String? wicketKeeperId;
  final void Function(LineupPlayer player) onSelected;

  String get _battingLabel {
    if (innings.battingTeamId == match.teamAId) return match.teamAName;
    if (innings.battingTeamId == match.teamBId) return match.teamBName;
    return match.teamAName;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) {
        return Material(
          color: AppColors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Column(
            children: [
              AppBar(
                title: Text('Select bowler — over $overNumber'),
                backgroundColor: AppColors.surface,
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(AppDimens.spaceMd),
                child: Text(
                  '$_battingLabel: ${innings.totalRuns}/${innings.totalWickets} '
                  '(${CricketMath.formatOvers(innings.legalBalls, ballsPerOver)} ov)',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (excludedBowlerIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceMd,
                  ),
                  child: Text(
                    'Previous over bowler cannot bowl again immediately',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  itemCount: bowlingSquad.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = bowlingSquad[i];
                    final isKeeper = wicketKeeperId != null &&
                        wicketKeeperId!.isNotEmpty &&
                        p.id == wicketKeeperId;
                    final excluded = excludedBowlerIds.contains(p.id) || isKeeper;
                    BowlerInningsModel? stats;
                    for (final b in innings.bowlers) {
                      if (b.playerId == p.id) {
                        stats = b;
                        break;
                      }
                    }
                    final overs = stats != null
                        ? CricketMath.formatOvers(
                            stats.oversBowledBalls,
                            ballsPerOver,
                          )
                        : '0.0';
                    final maxBalls = match.rules.maxBowlerLegalBalls;
                    final atMaxOvers =
                        stats != null && stats.oversBowledBalls >= maxBalls;
                    final disabled = excluded || atMaxOvers;
                    final selected = innings.currentBowlerId == p.id;
                    return ListTile(
                      enabled: !disabled,
                      leading: CircleAvatar(
                        backgroundColor: excluded
                            ? AppColors.surface
                            : selected
                                ? AppColors.primaryBlue
                                : AppColors.surfaceElevated,
                        child: Icon(
                          Icons.sports_baseball_outlined,
                          size: 20,
                          color: excluded
                              ? AppColors.textMuted
                              : selected
                                  ? AppColors.gold
                                  : AppColors.textSecondary,
                        ),
                      ),
                      title: Text(
                        p.name,
                        style: TextStyle(
                          color: excluded ? AppColors.textMuted : null,
                        ),
                      ),
                      subtitle: Text(
                        isKeeper
                            ? 'Current wicketkeeper cannot bowl'
                            : excluded && excludedBowlerIds.contains(p.id)
                                ? 'Bowled last over'
                                : atMaxOvers
                                    ? 'Max ${match.rules.totalOvers} overs bowled'
                                    : '$overs over(s)',
                      ),
                      trailing: selected && !disabled
                          ? const Icon(Icons.check_circle, color: AppColors.gold)
                          : null,
                      onTap: disabled
                          ? null
                          : () {
                              onSelected(p);
                              Navigator.pop(context);
                            },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
