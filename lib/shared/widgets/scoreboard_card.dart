import 'package:flutter/material.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/models/innings_model.dart';
import '../../data/models/match_model.dart';
import 'match_card_ui.dart';

/// Hero scorebug for match hub, scorecard header, and live contexts.
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
    final cur = innings ?? match.currentInnings;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceXs,
      ),
      decoration: matchHeroCardDecoration(match, context),
      child: Padding(
        padding: AppDimens.cardPadding,
        child: MatchCardContent(
          match: match,
          style: MatchCardStyle.hero,
          showFooterHint: false,
          showTossLine: cur != null,
        ),
      ),
    );
  }
}
