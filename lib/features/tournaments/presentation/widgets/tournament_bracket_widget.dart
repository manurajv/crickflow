import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/bracket_models.dart';
import '../../../../data/models/tournament_model.dart';

/// Horizontal knockout bracket view (round 1 + TBD later rounds).
class TournamentBracketWidget extends StatelessWidget {
  const TournamentBracketWidget({
    super.key,
    required this.tournament,
    this.existingMatchIds = const {},
  });

  final TournamentModel tournament;
  final Set<String> existingMatchIds;

  static const _roundColumnWidth = 180.0;

  @override
  Widget build(BuildContext context) {
    if (tournament.bracketRounds.isEmpty) {
      return const SizedBox.shrink();
    }

    final cf = context.cf;
    final roundCount = tournament.bracketRounds.length;
    final maxSlots = tournament.bracketRounds
        .map((round) => round.length)
        .fold<int>(0, (max, count) => count > max ? count : max);
    final bracketHeight = (56 + maxSlots * 76.0).clamp(180.0, 320.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Knockout bracket',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        Card(
          elevation: 0,
          color: cf.sectionBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: cf.border),
          ),
          child: SizedBox(
            height: bracketHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              itemCount: roundCount,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, roundIndex) {
                final slots = tournament.bracketRounds[roundIndex];
                return SizedBox(
                  width: _roundColumnWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _roundLabel(roundIndex, roundCount),
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: cf.accent,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: slots.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, slotIndex) {
                            final slot = slots[slotIndex];
                            final matchId = slot.matchId;
                            final matchExists = matchId != null &&
                                matchId.isNotEmpty &&
                                (existingMatchIds.isEmpty ||
                                    existingMatchIds.contains(matchId));
                            return _BracketSlotCard(
                              slot: slot,
                              onTap: matchExists
                                  ? () =>
                                      context.push('/match/$matchId')
                                  : null,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  String _roundLabel(int index, int totalRounds) {
    final remaining = totalRounds - index;
    if (remaining == 1) return 'Final';
    if (remaining == 2) return 'Semi-final';
    if (remaining == 3) return 'Quarter-final';
    return 'Round ${index + 1}';
  }
}

class _BracketSlotCard extends StatelessWidget {
  const _BracketSlotCard({required this.slot, this.onTap});

  final BracketSlotModel slot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final hasWinner = slot.winnerTeamName.isNotEmpty;
    final isTbd = slot.teamAName == 'TBD' && slot.teamBName == 'TBD';
    final isBye = slot.isBye;

    return Material(
      color: cf.card,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasWinner ? cf.accent.withValues(alpha: 0.5) : cf.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasWinner)
                Text(
                  slot.winnerTeamName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cf.accent,
                      ),
                )
              else if (isTbd)
                Text(
                  'TBD vs TBD',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cf.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                )
              else if (isBye)
                Text(
                  '${slot.teamAName} (bye)',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else ...[
                _TeamLine(name: slot.teamAName),
                const SizedBox(height: 4),
                Text(
                  'vs',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cf.textMuted,
                      ),
                ),
                const SizedBox(height: 4),
                _TeamLine(name: slot.teamBName),
              ],
              if (slot.matchId != null && onTap != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Tap to open',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cf.textMuted,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamLine extends StatelessWidget {
  const _TeamLine({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}
