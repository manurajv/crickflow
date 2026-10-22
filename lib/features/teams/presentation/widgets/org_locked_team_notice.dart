import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/team_model.dart';
import '../../../../shared/providers/providers.dart';

/// Shown on an org-linked team: details and squad are managed in the org.
class OrgLockedTeamNotice extends StatelessWidget {
  const OrgLockedTeamNotice({super.key, required this.lock});

  final TeamOrgLock lock;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final org = lock.seriesName.isEmpty ? 'an organization' : lock.seriesName;
    return Material(
      color: cf.accent.withValues(alpha: cf.isLight ? 0.08 : 0.14),
      child: InkWell(
        key: const Key('org_locked_team_notice'),
        onTap: () => context.push(lock.orgTeamPath),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: AppDimens.spaceSm,
          ),
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 18, color: cf.accent),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: Text(
                  'Managed by $org. Name and squad change only through the '
                  'org. Guests can still play in matches.',
                  style: TextStyle(color: cf.textSecondary, fontSize: 13),
                ),
              ),
              Icon(Icons.chevron_right, color: cf.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Route guard for team edit / add-player screens.
class OrgLockedTeamGate extends ConsumerWidget {
  const OrgLockedTeamGate({
    super.key,
    required this.teamId,
    required this.title,
    required this.child,
  });

  final String teamId;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(teamByIdProvider(teamId)).valueOrNull;
    final lock = team?.orgLock;
    if (lock == null) return child;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'This team belongs to an org. Its name, details and squad can '
              'only be changed through the org’s requests and approvals.',
            ),
            const SizedBox(height: AppDimens.spaceMd),
            FilledButton.icon(
              onPressed: () => context.push(lock.orgTeamPath),
              icon: const Icon(Icons.apartment_outlined),
              label: const Text('Open org team'),
            ),
          ],
        ),
      ),
    );
  }
}
