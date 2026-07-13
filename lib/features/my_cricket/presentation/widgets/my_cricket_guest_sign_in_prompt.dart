import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../shared/widgets/cf_button.dart';

/// Sign-in gate for guest users on My Cricket tabs.
class MyCricketGuestSignInPrompt extends StatelessWidget {
  const MyCricketGuestSignInPrompt({
    super.key,
    this.title = 'Sign in to view your details',
    this.subtitle =
        'Sign in with a CrickFlow account to see your matches, teams, '
        'stats, and highlights.',
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _CompactGuestSignInBanner(title: title, subtitle: subtitle);
    }

    final cf = context.cf;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppDimens.listPadding,
      children: [
        const SizedBox(height: 48),
        Icon(Icons.person_outline, size: 64, color: cf.textMuted),
        const SizedBox(height: AppDimens.spaceMd),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDimens.spaceSm),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cf.textSecondary,
              ),
        ),
        const SizedBox(height: AppDimens.spaceXl),
        Center(
          child: CfButton(
            label: 'Sign in',
            isGold: true,
            onPressed: () => context.push('/login'),
          ),
        ),
      ],
    );
  }
}

class _CompactGuestSignInBanner extends StatelessWidget {
  const _CompactGuestSignInBanner({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceSm,
        AppDimens.spaceMd,
        0,
      ),
      decoration: BoxDecoration(
        color: cf.sectionBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cf.border),
      ),
      child: ListTile(
        leading: Icon(Icons.person_outline, color: cf.accent),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cf.textSecondary,
              ),
        ),
        trailing: TextButton(
          onPressed: () => context.push('/login'),
          child: const Text('Sign in'),
        ),
      ),
    );
  }
}
