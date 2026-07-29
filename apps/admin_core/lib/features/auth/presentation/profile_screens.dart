import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../models/admin_permission.dart';
import '../../../shared/widgets/cf_card.dart';
import '../../shell/providers/shell_providers.dart';
import '../providers/auth_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(breadcrumbProvider.notifier).state = ['Profile'];
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(adminSessionProvider);
    final admin = session.adminUser;
    final colors = context.adminColors;

    return PermissionGate(
      permission: AdminPermission.canViewProfile,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: CfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Account details for the signed-in administrator.',
                  style: TextStyle(color: colors.textSecondary),
                ),
                const SizedBox(height: 24),
                _row('Name', admin?.displayName ?? '—'),
                _row('Email', admin?.email ?? session.firebaseUser?.email ?? '—'),
                _row('Role', admin?.roleLabel ?? '—'),
                _row('Role ID', admin?.roleId ?? '—'),
                _row('Organization', admin?.organizationName ?? admin?.organizationId ?? '—'),
                _row('Status', admin?.isActive == true ? 'Active' : 'Inactive'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(breadcrumbProvider.notifier).state = ['Account Settings'];
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return PermissionGate(
      permission: AdminPermission.canManageAccount,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: CfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account settings',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Password and security settings will be expanded in a later phase. Use Forgot password on the login screen to reset credentials.',
                  style: TextStyle(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
