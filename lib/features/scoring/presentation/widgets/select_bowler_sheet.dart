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
  });

  final MatchModel match;
  final InningsModel innings;
  final List<LineupPlayer> bowlingSquad;
  final int overNumber;
  final int ballsPerOver;
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
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  itemCount: bowlingSquad.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = bowlingSquad[i];
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
                    final selected = innings.currentBowlerId == p.id;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: selected
                            ? AppColors.primaryBlue
                            : AppColors.surfaceElevated,
                        child: Text(
                          p.name.isNotEmpty ? p.name[0] : '?',
                          style: TextStyle(
                            color: selected ? AppColors.gold : null,
                          ),
                        ),
                      ),
                      title: Text(p.name),
                      subtitle: Text('$overs over(s)'),
                      trailing: selected
                          ? const Icon(Icons.check_circle, color: AppColors.gold)
                          : null,
                      onTap: () {
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
