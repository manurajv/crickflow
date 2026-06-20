import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';

class MatchMvpHowScreen extends StatelessWidget {
  const MatchMvpHowScreen({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;

    return Scaffold(
      backgroundColor: cf.background,
      appBar: AppBar(
        title: const Text('How MVP is Calculated'),
      ),
      body: ListView(
        padding: AppDimens.listPadding,
        children: [
          Text(
            'CrickFlow MVP adapts to your match format — overs, balls per over, and match type — so performances stay fair from T10 to Test.',
            style: TextStyle(color: cf.textSecondary, height: 1.45),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          _InfoCard(
            cf: cf,
            title: 'Batting MVP',
            icon: Icons.sports_cricket_outlined,
            bullets: const [
              'Runs are valued against a dynamic par score for the match length.',
              'Strike rate bonus scales up in shorter formats and down in Tests.',
              'Boundary hitting and death-overs impact add extra credit.',
              'Big partnerships and winning chase contributions earn clutch bonuses.',
            ],
          ),
          _InfoCard(
            cf: cf,
            title: 'Bowling MVP',
            icon: Icons.sports_baseball_outlined,
            bullets: const [
              'Wickets are weighted by batting order — top-order dismissals score higher.',
              'Economy is compared to a format par (tight in T10, different in Tests).',
              'Dot balls, maidens, and death-overs wickets boost the score.',
              'Match-turning spells (quick wicket clusters) earn clutch bonuses.',
            ],
          ),
          _InfoCard(
            cf: cf,
            title: 'Fielding MVP',
            icon: Icons.back_hand_outlined,
            bullets: const [
              'Catches, stumpings, and run outs all add fielding MVP.',
              'Direct-hit run outs score highest among fielding actions.',
              'Catches removing top-order batters count as important catches.',
            ],
          ),
          _InfoCard(
            cf: cf,
            title: 'Player Of The Match',
            icon: Icons.emoji_events_outlined,
            bullets: const [
              'Awarded automatically to the #1 ranked MVP player.',
              'Reflects the best overall impact across bat, ball, and field.',
            ],
          ),
          _InfoCard(
            cf: cf,
            title: 'Fighter Of The Match',
            icon: Icons.shield_outlined,
            bullets: const [
              'Recognises the best performer from the losing team.',
              'Only players in the top 3 MVP scores of the losing side are eligible.',
              'The highest overall-ranked eligible player wins.',
              'Not awarded separately if the MVP winner is already from the losing team.',
            ],
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Container(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            decoration: BoxDecoration(
              color: cf.sectionBackground,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              border: Border.all(color: cf.border),
            ),
            child: Text(
              'Total MVP = Batting + Bowling + Fielding + clutch & partnership bonuses. '
              'Tap any player on the MVP tab to expand their breakdown.',
              style: TextStyle(color: cf.textSecondary, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.cf,
    required this.title,
    required this.icon,
    required this.bullets,
  });

  final CfColors cf;
  final String title;
  final IconData icon;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: cf.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: cf.border),
        boxShadow: [
          BoxShadow(
            color: cf.cardShadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: cf.accent, size: 22),
              const SizedBox(width: AppDimens.spaceSm),
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: cf.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceSm),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: TextStyle(color: cf.accent)),
                  Expanded(
                    child: Text(
                      b,
                      style: TextStyle(
                        color: cf.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
