import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/admin_route_paths.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../providers/shell_providers.dart';

class AdminTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const AdminTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.adminColors;
    final crumbs = ref.watch(breadcrumbProvider);
    final collapsed = ref.watch(sidebarCollapsedProvider);
    final session = ref.watch(adminSessionProvider);
    final admin = session.adminUser;

    return Material(
      color: colors.surface,
      elevation: 0,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.border)),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: collapsed ? 'Expand navigation' : 'Collapse navigation',
              onPressed: () {
                ref.read(sidebarCollapsedProvider.notifier).state = !collapsed;
              },
              icon: const Icon(Icons.menu),
            ),
            const SizedBox(width: 8),
            Expanded(child: _Breadcrumbs(crumbs: crumbs)),
            IconButton(
              tooltip: 'Notifications',
              onPressed: () {
                showMenu<void>(
                  context: context,
                  position: const RelativeRect.fromLTRB(1000, 64, 24, 0),
                  items: const [
                    PopupMenuItem(
                      enabled: false,
                      child: Text('No notifications yet'),
                    ),
                  ],
                );
              },
              icon: const Icon(Icons.notifications_outlined),
            ),
            const SizedBox(width: 4),
            _ProfileMenu(
              name: admin?.displayName ?? admin?.email ?? 'Admin',
              role: admin?.roleLabel ?? session.role?.label ?? '',
              initials: admin?.initials ?? '?',
              photoUrl: admin?.photoUrl ?? session.firebaseUser?.photoURL,
            ),
          ],
        ),
      ),
    );
  }
}

class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs({required this.crumbs});

  final List<String> crumbs;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < crumbs.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.chevron_right, size: 16, color: colors.textMuted),
              ),
            Text(
              crumbs[i],
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight:
                        i == crumbs.length - 1 ? FontWeight.w700 : FontWeight.w500,
                    color: i == crumbs.length - 1
                        ? colors.textPrimary
                        : colors.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileMenu extends ConsumerWidget {
  const _ProfileMenu({
    required this.name,
    required this.role,
    required this.initials,
    this.photoUrl,
  });

  final String name;
  final String role;
  final String initials;
  final String? photoUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) async {
        if (value == 'profile') {
          context.go(AdminRoutePaths.profile);
        } else if (value == 'settings') {
          context.go(AdminRoutePaths.accountSettings);
        } else if (value == 'theme') {
          ref.read(themeModeProvider.notifier).state =
              isDark ? ThemeMode.light : ThemeMode.dark;
        } else if (value == 'logout') {
          await ref.read(authServiceProvider).signOut();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(role, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'profile',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.person_outline),
            title: Text('Profile'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'settings',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.manage_accounts_outlined),
            title: Text('Account Settings'),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'theme',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            title: Text(isDark ? 'Light mode' : 'Dark mode'),
            dense: true,
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout),
            title: Text('Logout'),
            dense: true,
          ),
        ),
      ],
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AdminColors.primaryBlue,
            backgroundImage:
                photoUrl != null ? NetworkImage(photoUrl!) : null,
            child: photoUrl == null
                ? Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(
                  role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.adminColors.textMuted,
                      ),
                ),
              ],
            ),
          ),
          const Icon(Icons.keyboard_arrow_down, size: 18),
        ],
      ),
    );
  }
}
