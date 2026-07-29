import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../../models/admin_permission.dart';
import '../../shared/widgets/cf_empty_state.dart';

/// Blocks page content unless the signed-in admin has [permission].
///
/// Prefer declaring requirements in [AdminRoutePermissions] so GoRouter also
/// redirects. This widget is a second line of defense inside the page.
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

/// Convenience gate for multiple permissions (any / all).
class PermissionGateAny extends ConsumerWidget {
  const PermissionGateAny({
    super.key,
    required this.permissions,
    required this.child,
    this.requireAll = false,
    this.fallback,
  });

  final List<AdminPermission> permissions;
  final Widget child;
  final bool requireAll;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checker = ref.watch(permissionCheckerProvider);
    final allowed =
        requireAll ? checker.canAll(permissions) : checker.canAny(permissions);
    if (allowed) return child;
    return fallback ??
        const CfEmptyState(
          icon: Icons.lock_outline,
          title: 'Permission required',
          message: 'You do not have access to this section.',
        );
  }
}
