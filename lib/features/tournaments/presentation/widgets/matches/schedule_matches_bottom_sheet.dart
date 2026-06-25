import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../data/models/tournament_model.dart';
import '../../utils/tournament_display_utils.dart';
import 'auto_fixture_sheet.dart';
import 'manual_match_schedule_sheet.dart';

Future<void> showScheduleMatchesBottomSheet({
  required BuildContext context,
  required TournamentModel tournament,
  required bool canManage,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    builder: (ctx) => _ScheduleMatchesSheet(
      tournament: tournament,
      canManage: canManage,
    ),
  );
}

class _ScheduleMatchesSheet extends StatelessWidget {
  const _ScheduleMatchesSheet({
    required this.tournament,
    required this.canManage,
  });

  final TournamentModel tournament;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Padding(
      padding: AppDimens.screenPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
              decoration: BoxDecoration(
                color: cf.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Text(
            'How would you like to schedule?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'Format: ${tournamentFormatLabel(tournament.format)}. '
            'Auto-generate uses this format by default.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cf.textSecondary,
                ),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          _OptionTile(
            icon: Icons.edit_calendar_outlined,
            title: 'Manual Schedule',
            subtitle: 'Pick round, teams, venue and save one match at a time.',
            onTap: canManage
                ? () {
                    Navigator.pop(context);
                    showManualMatchScheduleSheet(
                      context: context,
                      tournament: tournament,
                    );
                  }
                : null,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          _OptionTile(
            icon: Icons.auto_fix_high_outlined,
            title: 'Auto Generate Fixtures',
            subtitle: 'League, group stage, knockout or hybrid from current teams.',
            onTap: canManage
                ? () {
                    Navigator.pop(context);
                    showAutoFixtureSheet(
                      context: context,
                      tournament: tournament,
                    );
                  }
                : null,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          _OptionTile(
            icon: Icons.layers_outlined,
            title: 'Manage Rounds',
            subtitle: 'Create league, knockout and custom rounds.',
            onTap: () {
              Navigator.pop(context);
              context.push('/tournaments/${tournament.id}/rounds');
            },
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom + AppDimens.spaceMd),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Material(
      color: cf.surfaceElevated,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: AppDimens.cardPadding,
          child: Row(
            children: [
              Icon(icon, color: onTap == null ? cf.textMuted : cf.accent),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: onTap == null ? cf.textMuted : null,
                          ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cf.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cf.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
