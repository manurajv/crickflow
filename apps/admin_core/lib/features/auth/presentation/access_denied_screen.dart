import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../../shared/widgets/cf_empty_state.dart';
import '../providers/auth_providers.dart';

class AccessDeniedScreen extends ConsumerWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(adminSessionProvider);
    final appType = ref.watch(adminAppTypeProvider);
    final colors = context.adminColors;

    final message = switch (session.status) {
      AdminSessionStatus.noAdminProfile =>
        'No admin profile is linked to this account. Contact a platform owner.',
      AdminSessionStatus.inactive =>
        'This admin account is inactive.',
      AdminSessionStatus.wrongPanel => appType == AdminAppType.superAdmin
          ? 'This account is not a Super Admin. Use the Organization Admin panel instead.'
          : 'This account cannot access the Organization Admin panel. Use the Super Admin panel if you are a platform owner.',
      _ => 'You are not authorized to use this panel.',
    };

    return Scaffold(
      body: CfEmptyState(
        icon: Icons.gpp_bad_outlined,
        title: 'Access denied',
        message: message,
        action: Column(
          children: [
            if (session.adminUser != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Signed in as ${session.adminUser!.email} '
                  '(${session.adminUser!.platformRole.label})',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textMuted,
                      ),
                ),
              ),
            CfButton(
              label: 'Sign out',
              variant: CfButtonVariant.secondary,
              onPressed: () => ref.read(authServiceProvider).signOut(),
            ),
          ],
        ),
      ),
    );
  }
}
