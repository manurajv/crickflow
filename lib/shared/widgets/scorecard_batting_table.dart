import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/cricket_math.dart';
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
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No batting data yet',
          style: TextStyle(color: AppColors.textSecondary),
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
    const style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
    );
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('Batter', style: style)),
          Expanded(child: Text('R', style: style, textAlign: TextAlign.end)),
          Expanded(child: Text('B', style: style, textAlign: TextAlign.end)),
          Expanded(child: Text('4s', style: style, textAlign: TextAlign.end)),
          Expanded(child: Text('6s', style: style, textAlign: TextAlign.end)),
          Expanded(child: Text('SR', style: style, textAlign: TextAlign.end)),
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
                    color: AppColors.primaryBlue,
                  ),
                ),
                if (dismissal.isNotEmpty)
                  Text(
                    dismissal,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
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
    this.ballsPerOver = 6,
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
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  String _overLabel(int legalBalls) {
    return '${CricketMath.formatOvers(legalBalls, ballsPerOver)} Ov';
  }
}
