import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/models/match_model.dart';
import 'match_card_ui.dart';

/// Compact match card for list feeds (Home, My Cricket, Discover).
class MatchListCard extends StatelessWidget {
  const MatchListCard({
    super.key,
    required this.match,
    this.tournamentLabel,
    this.showQuickLinks = true,
  });

  final MatchModel match;
  final String? tournamentLabel;
  final bool showQuickLinks;

  @override
  Widget build(BuildContext context) {
    final isCompleted = match.status == MatchStatus.completed;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceXs,
      ),
      decoration: matchListCardDecoration(match),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push('/match/${match.id}'),
              child: Padding(
                padding: AppDimens.cardPadding,
                child: MatchCardContent(
                  match: match,
                  tournamentLabel: tournamentLabel,
                ),
              ),
            ),
          ),
          if (showQuickLinks) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _LinkButton(
                    label: 'Insights',
                    onTap: () =>
                        context.push('/match/${match.id}?tab=insights'),
                  ),
                  _LinkButton(
                    label: 'Scorecard',
                    onTap: () =>
                        context.push('/match/${match.id}?tab=scorecard'),
                  ),
                  if (isCompleted)
                    _LinkButton(
                      label: 'Highlights',
                      onTap: () =>
                          context.push('/match/${match.id}?tab=highlights'),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.primaryBlueLight,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
      ),
    );
  }
}
