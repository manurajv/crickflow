import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../models/admin_permission.dart';
import '../../../../models/admin_role.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../models/managed_user.dart';
import '../../models/user_account_status.dart';
import '../../providers/users_providers.dart';
import 'user_status_badge.dart';

class UserDetailPanel extends ConsumerWidget {
  const UserDetailPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(selectedManagedUserProvider);
    final colors = context.adminColors;
    final canManage =
        ref.watch(permissionCheckerProvider).can(AdminPermission.canManageUsers);

    return Material(
      color: colors.surface,
      elevation: 8,
      child: SizedBox(
        width: 440,
        child: async.when(
          loading: () => const CfLoadingState(message: 'Loading profile…'),
          error: (e, _) => Center(child: Text('$e')),
          data: (user) {
            if (user == null) {
              return const Center(child: Text('Select a user'));
            }
            return Column(
              children: [
                _Header(onClose: onClose),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                      _ProfileBlock(user: user),
                      const SizedBox(height: 16),
                      _InfoGrid(user: user),
                      const SizedBox(height: 16),
                      _StatsRow(user: user),
                      const SizedBox(height: 16),
                      if (canManage) ...[
                        _ActionsSection(user: user),
                        const SizedBox(height: 16),
                      ],
                      const _SectionTitle('Activity'),
                      const SizedBox(height: 8),
                      const _ActivityList(),
                      const SizedBox(height: 16),
                      const _SectionTitle('Related (placeholders)'),
                      const SizedBox(height: 8),
                      const _PlaceholderList(
                        items: [
                          'Recent matches',
                          'Recent tournaments',
                          'Recent reports',
                          'Community posts',
                          'Discover posts',
                          'Notifications',
                          'Login history',
                          'Devices',
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'User details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }
}

class _ProfileBlock extends StatelessWidget {
  const _ProfileBlock({required this.user});

  final ManagedUser user;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Column(
      children: [
        Container(
          height: 96,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: colors.background,
            image: user.coverUrl != null
                ? DecorationImage(
                    image: NetworkImage(user.coverUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
            border: Border.all(color: colors.border),
          ),
          child: user.coverUrl == null
              ? Icon(Icons.image_outlined, color: colors.textMuted)
              : null,
        ),
        Transform.translate(
          offset: const Offset(0, -28),
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: AdminColors.primaryBlue,
                backgroundImage:
                    user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                child: user.photoUrl == null
                    ? Text(
                        user.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                user.effectiveName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Text('@${user.username}', style: TextStyle(color: colors.textMuted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  UserStatusBadge(status: user.accountStatus),
                  VerifiedBadge(verified: user.adminVerified),
                  Chip(
                    label: Text(user.roleLabel),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.user});

  final ManagedUser user;

  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<String, String>>[
      MapEntry('Email', user.email.isEmpty ? '—' : user.email),
      MapEntry('Phone', user.phoneNumber ?? '—'),
      MapEntry('Player ID', user.playerId ?? '—'),
      MapEntry(
        'DOB',
        user.dateOfBirth == null
            ? '—'
            : DateFormat('yyyy-MM-dd').format(user.dateOfBirth!),
      ),
      MapEntry('Country', user.country.isEmpty ? '—' : user.country),
      MapEntry(
        'State',
        user.stateProvince.isEmpty ? '—' : user.stateProvince,
      ),
      MapEntry('City', user.city.isEmpty ? '—' : user.city),
      MapEntry('Team', user.currentTeamName ?? user.currentTeamId ?? '—'),
      MapEntry('Followers', '${user.followers}'),
      MapEntry('Following', '${user.following}'),
      MapEntry(
        'Joined',
        user.createdAt == null
            ? '—'
            : DateFormat('yyyy-MM-dd HH:mm').format(user.createdAt!),
      ),
      MapEntry(
        'Last login',
        user.lastLoginAt == null
            ? '—'
            : DateFormat('yyyy-MM-dd HH:mm').format(user.lastLoginAt!),
      ),
      if (user.isSoftDeleted) ...[
        MapEntry(
          'Deleted at',
          user.deletedAt == null
              ? '—'
              : DateFormat('yyyy-MM-dd HH:mm').format(user.deletedAt!),
        ),
        MapEntry('Deleted by', user.deletedBy ?? '—'),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Profile'),
        const SizedBox(height: 8),
        if (user.bio.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(user.bio),
          ),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    row.key,
                    style: TextStyle(
                      color: context.adminColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(child: Text(row.value)),
              ],
            ),
          ),
        if (user.badgeIds.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: [
              for (final b in user.badgeIds.take(8)) Chip(label: Text(b)),
            ],
          ),
        ],
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.user});

  final ManagedUser user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _stat(context, 'Matches', '${user.matchesPlayed}'),
        _stat(context, 'Scored', '${user.matchesScored}'),
        _stat(context, 'Tournaments', '${user.tournamentsOrganized}'),
      ],
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    final colors = context.adminColors;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(label, style: TextStyle(color: colors.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _ActionsSection extends ConsumerWidget {
  const _ActionsSection({required this.user});

  final ManagedUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(usersListControllerProvider.notifier);
    final isSuper =
        AdminRole.tryParse(ref.watch(adminSessionProvider).adminUser?.roleId) ==
            AdminRole.superAdmin;

    Future<void> confirmAction({
      required String title,
      required String message,
      required Future<void> Function(String? reason) run,
      bool danger = false,
    }) async {
      final reasonController = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                ),
              ),
            ],
          ),
          actions: [
            CfButton(
              label: 'Cancel',
              variant: CfButtonVariant.ghost,
              onPressed: () => Navigator.pop(context, false),
            ),
            CfButton(
              label: 'Confirm',
              variant: danger ? CfButtonVariant.danger : CfButtonVariant.primary,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );
      if (ok == true) {
        try {
          await run(
            reasonController.text.trim().isEmpty
                ? null
                : reasonController.text.trim(),
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$title completed')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$e')),
            );
          }
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Actions'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () async {
                final path = '/player/${user.id}';
                final uri = Uri.parse(
                  'https://crickflow.app/open-app.html?path=${Uri.encodeComponent(path)}',
                );
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              child: const Text('Open Mobile Profile'),
            ),
            OutlinedButton(
              onPressed: () => _editBasic(context, ref, user),
              child: const Text('Edit basic info'),
            ),
            OutlinedButton(
              onPressed: () => confirmAction(
                title: 'Reset password',
                message: 'Send a password reset email to ${user.email}?',
                run: (reason) =>
                    controller.resetPassword(user, reason: reason),
              ),
              child: const Text('Reset password'),
            ),
            OutlinedButton(
              onPressed: () => confirmAction(
                title: user.adminVerified ? 'Remove verification' : 'Verify user',
                message: user.adminVerified
                    ? 'Remove admin verification from this account?'
                    : 'Mark this user as verified?',
                run: (reason) => controller.setVerified(
                  user,
                  !user.adminVerified,
                  reason: reason,
                ),
              ),
              child: Text(user.adminVerified ? 'Remove verification' : 'Verify'),
            ),
            if (user.accountStatus != UserAccountStatus.suspended)
              OutlinedButton(
                onPressed: () => confirmAction(
                  title: 'Suspend user',
                  message: 'Suspend ${user.effectiveName}?',
                  danger: true,
                  run: (reason) => controller.setStatus(
                    user,
                    UserAccountStatus.suspended,
                    reason: reason,
                  ),
                ),
                child: const Text('Suspend'),
              )
            else
              OutlinedButton(
                onPressed: () => confirmAction(
                  title: 'Unsuspend user',
                  message: 'Restore ${user.effectiveName} to active?',
                  run: (reason) => controller.setStatus(
                    user,
                    UserAccountStatus.active,
                    reason: reason,
                  ),
                ),
                child: const Text('Unsuspend'),
              ),
            if (user.accountStatus != UserAccountStatus.banned)
              OutlinedButton(
                onPressed: () => confirmAction(
                  title: 'Ban user',
                  message: 'Ban ${user.effectiveName}? This is restrictive.',
                  danger: true,
                  run: (reason) => controller.setStatus(
                    user,
                    UserAccountStatus.banned,
                    reason: reason,
                  ),
                ),
                child: const Text('Ban'),
              )
            else
              OutlinedButton(
                onPressed: () => confirmAction(
                  title: 'Unban user',
                  message: 'Remove ban from ${user.effectiveName}?',
                  run: (reason) => controller.setStatus(
                    user,
                    UserAccountStatus.active,
                    reason: reason,
                  ),
                ),
                child: const Text('Unban'),
              ),
            if (user.accountStatus != UserAccountStatus.deleted)
              OutlinedButton(
                onPressed: () => confirmAction(
                  title: 'Soft-delete account',
                  message:
                      'Mark ${user.effectiveName} as deleted?\n\n'
                      'This is a soft delete: the profile, match history, '
                      'teams, tournaments, and stats stay in Firestore and '
                      'can be restored. No documents are permanently removed.',
                  danger: true,
                  run: (reason) => controller.setStatus(
                    user,
                    UserAccountStatus.deleted,
                    reason: reason,
                  ),
                ),
                child: const Text('Delete'),
              )
            else
              OutlinedButton(
                onPressed: () => confirmAction(
                  title: 'Restore account',
                  message:
                      'Restore ${user.effectiveName}?\n\n'
                      'Clears soft-delete markers and sets status back to Active.',
                  run: (reason) => controller.setStatus(
                    user,
                    UserAccountStatus.active,
                    reason: reason,
                  ),
                ),
                child: const Text('Restore'),
              ),
            if (isSuper)
              OutlinedButton(
                onPressed: () => _changeRole(context, ref, user),
                child: const Text('Change admin role'),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _editBasic(
    BuildContext context,
    WidgetRef ref,
    ManagedUser user,
  ) async {
    final name = TextEditingController(text: user.displayName);
    final phone = TextEditingController(text: user.phoneNumber ?? '');
    final bio = TextEditingController(text: user.bio);
    final country = TextEditingController(text: user.country);
    final state = TextEditingController(text: user.stateProvince);
    final city = TextEditingController(text: user.city);

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit basic information'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Display name'),
                ),
                TextField(
                  controller: phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                TextField(
                  controller: bio,
                  decoration: const InputDecoration(labelText: 'Bio'),
                  maxLines: 3,
                ),
                TextField(
                  controller: country,
                  decoration: const InputDecoration(labelText: 'Country'),
                ),
                TextField(
                  controller: state,
                  decoration: const InputDecoration(labelText: 'State'),
                ),
                TextField(
                  controller: city,
                  decoration: const InputDecoration(labelText: 'City'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          CfButton(
            label: 'Cancel',
            variant: CfButtonVariant.ghost,
            onPressed: () => Navigator.pop(context, false),
          ),
          CfButton(
            label: 'Save',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (ok == true) {
      await ref.read(usersListControllerProvider.notifier).saveBasicInfo(
            user,
            displayName: name.text.trim(),
            phoneNumber: phone.text.trim(),
            bio: bio.text.trim(),
            country: country.text.trim(),
            stateProvince: state.text.trim(),
            city: city.text.trim(),
          );
    }
  }

  Future<void> _changeRole(
    BuildContext context,
    WidgetRef ref,
    ManagedUser user,
  ) async {
    AdminRole? selected = user.adminRole;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Promote / demote role'),
          content: DropdownButtonFormField<AdminRole?>(
            // ignore: deprecated_member_use
            value: selected,
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('No admin role (User)'),
              ),
              for (final r in AdminRole.values)
                if (r != AdminRole.viewer)
                  DropdownMenuItem(value: r, child: Text(r.label)),
            ],
            onChanged: (v) => setLocal(() => selected = v),
          ),
          actions: [
            CfButton(
              label: 'Cancel',
              variant: CfButtonVariant.ghost,
              onPressed: () => Navigator.pop(context, false),
            ),
            CfButton(
              label: 'Save role',
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await ref.read(usersListControllerProvider.notifier).setAdminRole(
            user,
            selected,
          );
    }
  }
}

class _ActivityList extends ConsumerWidget {
  const _ActivityList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(selectedUserActivityProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text('$e'),
      data: (items) {
        if (items.isEmpty) {
          return Text(
            'No activity yet',
            style: TextStyle(color: context.adminColors.textMuted),
          );
        }
        return Column(
          children: [
            for (final item in items.take(12))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.timeline, size: 18),
                title: Text(item.title),
                subtitle: Text(item.subtitle),
                trailing: Text(
                  DateFormat('MMM d').format(item.occurredAt),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PlaceholderList extends StatelessWidget {
  const _PlaceholderList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Column(
      children: [
        for (final item in items)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(item),
            subtitle: Text(
              'Coming soon',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
            trailing:
                Icon(Icons.lock_outline, size: 16, color: colors.textMuted),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
  }
}
