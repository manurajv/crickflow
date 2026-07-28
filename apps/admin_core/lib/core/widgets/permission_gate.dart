import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../../models/admin_permission.dart';
import '../../shared/widgets/cf_empty_state.dart';

/// Blocks page content unless the signed-in admin has [permission].
class PermissionGate extends ConsumerWidget {
  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  final AdminPermission permission;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowed = ref.watch(permissionCheckerProvider).can(permission);
    if (allowed) return child;
    return fallback ??
        const CfEmptyState(
          icon: Icons.lock_outline,
          title: 'Permission required',
          message: 'You do not have access to this section.',
        );
  }
}
