import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../shared/providers/start_match_draft_provider.dart';
import '../../../shared/widgets/start_match_ui.dart';

/// Choose Normal Match vs Quick Match before entering the create flow.
class MatchTypeChoiceScreen extends ConsumerWidget {
  const MatchTypeChoiceScreen({super.key});

  void _startNormal(BuildContext context, WidgetRef ref) {
    ref.read(startMatchDraftProvider.notifier).reset(mode: MatchMode.normal);
    context.push('/match/create');
  }

  void _startQuick(BuildContext context, WidgetRef ref) {
    ref.read(startMatchDraftProvider.notifier).reset(mode: MatchMode.quick);
    context.push('/match/quick');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: cf.background,
      appBar: AppBar(title: const Text('Start a Match')),
      body: ListView(
        padding: AppDimens.listPadding,
        children: [
          StartMatchInfoBanner(
            message: 'Choose how you want to start. Normal Match keeps the full setup.',
          ),
          const SizedBox(height: AppDimens.spaceLg),
          Text(
            'Choose how you want to start',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cf.textPrimary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          _ModeCard(
            icon: Icons.playlist_add_check_circle_outlined,
            title: 'Normal Match',
            subtitle: 'Set up teams, Playing XI and match details',
            onTap: () => _startNormal(context, ref),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          _ModeCard(
            icon: Icons.bolt_outlined,
            title: 'Quick Match',
            subtitle: 'Start scoring faster without selecting a Playing XI',
            onTap: () => _startQuick(context, ref),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final theme = Theme.of(context);

    return StartMatchCard(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: cf.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: cf.accent, size: 28),
                ),
                const SizedBox(width: AppDimens.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cf.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cf.textSecondary,
                          height: 1.35,
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
      ),
    );
  }
}
