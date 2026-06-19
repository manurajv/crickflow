import 'package:flutter/material.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/cricket_math.dart';
import '../../../../data/models/innings_model.dart';
import '../../../../data/models/lineup_player.dart';
import '../../../../data/models/match_model.dart';
import '../../../../shared/widgets/lineup_player_avatar.dart';
import '../../../../shared/widgets/scoring_ui_kit.dart';
import '../utils/scoring_display_utils.dart';
import '../../../../core/theme/cf_colors.dart';

class SelectBowlerSheet extends StatelessWidget {
  const SelectBowlerSheet({
    super.key,
    required this.match,
    required this.innings,
    required this.bowlingSquad,
    required this.overNumber,
    required this.scrollController,
    this.excludedBowlerIds = const {},
    this.wicketKeeperId,
  });

  final MatchModel match;
  final InningsModel innings;
  final List<LineupPlayer> bowlingSquad;
  final int overNumber;
  final ScrollController scrollController;
  final Set<String> excludedBowlerIds;
  final String? wicketKeeperId;

  static Future<LineupPlayer?> show(
    BuildContext context, {
    required MatchModel match,
    required InningsModel innings,
    required List<LineupPlayer> bowlingSquad,
    required int overNumber,
    Set<String> excludedBowlerIds = const {},
    String? wicketKeeperId,
  }) {
    return ScoringUiKit.showDraggableSheet<LineupPlayer>(
      context,
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      builder: (ctx, controller) => SelectBowlerSheet(
        match: match,
        innings: innings,
        bowlingSquad: bowlingSquad,
        overNumber: overNumber,
        scrollController: controller,
        excludedBowlerIds: excludedBowlerIds,
        wicketKeeperId: wicketKeeperId,
      ),
    );
  }

  String get _battingLabel {
    if (innings.battingTeamId == match.teamAId) return match.teamAName;
    if (innings.battingTeamId == match.teamBId) return match.teamBName;
    return match.teamAName;
  }

  int get ballsPerOver => match.rules.ballsPerOver;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Material(
      color: cf.surface,
      child: Column(
        children: [
          ScoringSheetHeader(
            title: 'Select bowler — over $overNumber',
            trailing: ScoringUiKit.sheetCloseButton(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              0,
              AppDimens.spaceMd,
              AppDimens.spaceSm,
            ),
            child: Text(
              '$_battingLabel: ${innings.totalRuns}/${innings.totalWickets} '
              '(${CricketMath.formatOvers(innings.legalBalls, ballsPerOver)} ov)',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: cf.textPrimary,
              ),
            ),
          ),
          if (excludedBowlerIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                0,
                AppDimens.spaceMd,
                AppDimens.spaceSm,
              ),
              child: Text(
                'Previous over bowler cannot bowl again immediately',
                style: TextStyle(
                  fontSize: 12,
                  color: cf.textSecondary.withValues(alpha: 0.9),
                ),
              ),
            ),
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
              itemCount: bowlingSquad.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: cf.border),
              itemBuilder: (_, i) {
                final p = bowlingSquad[i];
                final isKeeper = wicketKeeperId != null &&
                    wicketKeeperId!.isNotEmpty &&
                    p.id == wicketKeeperId;
                final excluded =
                    excludedBowlerIds.contains(p.id) || isKeeper;
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
                  leading: LineupPlayerAvatar(
                    name: p.name,
                    photoUrl: p.photoUrl,
                    radius: 22,
                    backgroundColor: disabled
                        ? cf.surface
                        : selected
                            ? cf.accent.withValues(alpha: 0.15)
                            : cf.sectionBackground,
                    foregroundColor: disabled
                        ? cf.textMuted
                        : selected
                            ? cf.accent
                            : cf.textSecondary,
                  ),
                  title: Text(
                    p.name,
                    style: TextStyle(
                      color: disabled ? cf.textMuted : null,
                    ),
                  ),
                  subtitle: Text(
                    isKeeper
                        ? ScoringDisplayUtils.wicketKeeperCannotBowlReason
                        : excludedBowlerIds.contains(p.id)
                            ? 'Bowled last over'
                            : atMaxOvers
                                ? 'Max ${match.rules.totalOvers} overs bowled'
                                : '$overs over(s)',
                  ),
                  trailing: selected && !disabled
                      ? Icon(Icons.check_circle, color: cf.accent)
                      : null,
                  onTap: disabled
                      ? null
                      : () => Navigator.pop(context, p),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
