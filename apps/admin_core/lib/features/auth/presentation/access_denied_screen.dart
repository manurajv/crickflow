import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/router/admin_route_paths.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../../shared/widgets/cf_card.dart';
import '../providers/auth_providers.dart';

class AccessDeniedScreen extends ConsumerWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(adminSessionProvider);
    final appType = ref.watch(adminAppTypeProvider);
    final colors = context.adminColors;

    final detail = switch (session.status) {
      AdminSessionStatus.noAdminProfile =>
        'No administration profile is linked to this account.',
      AdminSessionStatus.inactive => 'This administration account is inactive.',
      AdminSessionStatus.unauthorizedRole =>
        'Your role (${session.adminUser?.roleLabel ?? 'unknown'}) does not have permission to access the administration system.',
      AdminSessionStatus.wrongPanel => appType == AdminAppType.superAdmin
          ? 'This account is not authorized for the Super Admin panel.'
          : 'This account is not authorized for the Organization Admin panel.',
      _ => null,
    };

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors.isLight
                ? const [Color(0xFFF4F6FA), Color(0xFFFFEBEE)]
                : const [Color(0xFF0A0E17), Color(0xFF1A1215)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: CfCard(
                padding: const EdgeInsets.all(36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: colors.error.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.gpp_bad_outlined,
                        size: 36,
                        color: colors.error,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Access denied',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "You don't have permission to access this application.",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: colors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Contact your administrator if you believe this is an error.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colors.textMuted,
                          ),
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        detail,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.textMuted,
                            ),
                      ),
                    ],
                    if (session.firebaseUser?.email != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        session.firebaseUser!.email!,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AdminColors.primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    CfButton(
                      label: 'Return to Login',
                      expanded: true,
                      onPressed: () async {
                        await ref.read(authServiceProvider).signOut();
                        if (context.mounted) {
                          context.go(AdminRoutePaths.login);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Authenticated but missing a specific route permission.
class ForbiddenScreen extends ConsumerWidget {
  const ForbiddenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.adminColors;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: CfCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 40, color: colors.warning),
                const SizedBox(height: 16),
                Text(
                  'Permission required',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You are signed in, but your role does not include access to this page.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textSecondary),
                ),
                const SizedBox(height: 24),
                CfButton(
                  label: 'Back to dashboard',
                  expanded: true,
                  onPressed: () => context.go(AdminRoutePaths.dashboard),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
