import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/bracket_models.dart';
import '../../../../data/models/tournament_model.dart';

/// Horizontal knockout bracket view (round 1 + TBD later rounds).
class TournamentBracketWidget extends StatelessWidget {
  const TournamentBracketWidget({
    super.key,
    required this.tournament,
  });

  final TournamentModel tournament;

  @override
  Widget build(BuildContext context) {
    if (tournament.bracketRounds.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            'Knockout bracket',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: tournament.bracketRounds.length,
            itemBuilder: (context, roundIndex) {
              final slots = tournament.bracketRounds[roundIndex];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _roundLabel(roundIndex, tournament.bracketRounds.length),
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: slots.length,
                        itemBuilder: (_, slotIndex) {
                          final slot = slots[slotIndex];
                          return _BracketSlotCard(
                            slot: slot,
                            onTap: slot.matchId != null
                                ? () => context.push('/match/${slot.matchId}')
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
    final hasWinner = slot.winnerTeamName.isNotEmpty;
    final label = hasWinner
        ? slot.winnerTeamName
        : '${slot.teamAName} vs ${slot.teamBName}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: hasWinner ? FontWeight.bold : FontWeight.normal,
                  color: hasWinner ? AppColors.gold : null,
                ),
              ),
              if (slot.matchId != null && onTap != null)
                const Text(
                  'Tap to open match',
                  style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
