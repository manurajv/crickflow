import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/cf_colors.dart';
import '../../core/utils/cricket_math.dart';
import '../../core/utils/overs_formatter.dart';
import '../../data/models/innings_model.dart';

/// Broadcast-style batting rows for scorecard screens.
class ScorecardBattingTable extends StatelessWidget {
  const ScorecardBattingTable({
    super.key,
    required this.batsmen,
    this.strikerId,
    this.nonStrikerId,
  });

  final List<BatsmanInningsModel> batsmen;
  final String? strikerId;
  final String? nonStrikerId;

  @override
  Widget build(BuildContext context) {
    if (batsmen.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No batting data yet',
          style: TextStyle(color: context.cf.textSecondary),
        ),
      );
    }

    return Column(
      children: [
        const _BattingHeader(),
        const Divider(height: 1),
        ...batsmen.map((b) => _BattingRow(
              batsman: b,
              isOnCrease: b.playerId == strikerId || b.playerId == nonStrikerId,
              isStriker: b.playerId == strikerId,
            )),
      ],
    );
  }
}

class _BattingHeader extends StatelessWidget {
  const _BattingHeader();

  @override
  Widget build(BuildContext context) {
    final headerStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: context.cf.textSecondary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('Batter', style: headerStyle)),
          Expanded(child: Text('R', style: headerStyle, textAlign: TextAlign.end)),
          Expanded(child: Text('B', style: headerStyle, textAlign: TextAlign.end)),
          Expanded(child: Text('4s', style: headerStyle, textAlign: TextAlign.end)),
          Expanded(child: Text('6s', style: headerStyle, textAlign: TextAlign.end)),
          Expanded(child: Text('SR', style: headerStyle, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

class _BattingRow extends StatelessWidget {
  const _BattingRow({
    required this.batsman,
    required this.isOnCrease,
    required this.isStriker,
  });

  final BatsmanInningsModel batsman;
  final bool isOnCrease;
  final bool isStriker;

  @override
  Widget build(BuildContext context) {
    final name = batsman.playerName.isNotEmpty
        ? batsman.playerName
        : batsman.playerId;
    final onCreaseSuffix = isOnCrease ? (isStriker ? '*' : '') : '';
    final dismissal = batsman.isOut
        ? batsman.dismissalInfo
        : (isOnCrease ? 'not out' : '');
    final sr = CricketMath.strikeRate(batsman.runs, batsman.balls);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name$onCreaseSuffix',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: CfColors.primaryBlue,
                  ),
                ),
                if (dismissal.isNotEmpty)
                  Text(
                    dismissal,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.cf.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              '${batsman.runs}',
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text('${batsman.balls}', textAlign: TextAlign.end),
          ),
          Expanded(
            child: Text('${batsman.fours}', textAlign: TextAlign.end),
          ),
          Expanded(
            child: Text('${batsman.sixes}', textAlign: TextAlign.end),
          ),
          Expanded(
            child: Text(
              sr.toStringAsFixed(1),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class ScorecardFallOfWickets extends StatelessWidget {
  const ScorecardFallOfWickets({
    super.key,
    required this.entries,
    this.ballsPerOver = AppConstants.defaultBallsPerOver,
  });

  final List<FallOfWicketRecord> entries;
  final int ballsPerOver;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fall of wickets',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        ...entries.map(
          (f) => Text(
            '${f.wicketNumber} ${f.batsmanName.isNotEmpty ? f.batsmanName : f.batsmanId} '
            '${f.teamScore} (${_overLabel(f.legalBalls)})',
            style: TextStyle(
              fontSize: 12,
              color: context.cf.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  String _overLabel(int legalBalls) {
    return '${OversFormatter.formatOvers(legalBalls, ballsPerOver)} Ov';
  }
}
