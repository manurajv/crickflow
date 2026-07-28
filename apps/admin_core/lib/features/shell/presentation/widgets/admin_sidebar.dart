import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/breakpoints.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../models/nav_models.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../providers/shell_providers.dart';

class AdminSidebar extends ConsumerWidget {
  const AdminSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collapsed = ref.watch(sidebarCollapsedProvider);
    final sections = ref.watch(navSectionsProvider);
    final appType = ref.watch(adminAppTypeProvider);
    final location = GoRouterState.of(context).uri.path;
    final width = collapsed
        ? Breakpoints.sidebarCollapsed
        : Breakpoints.sidebarExpanded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: width,
      color: context.adminColors.sidebar,
      child: Column(
        children: [
          _SidebarHeader(
            collapsed: collapsed,
            title: appType.displayName,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              children: [
                for (final section in sections) ...[
                  ..._buildSection(
                    context,
                    ref,
                    section: section,
                    collapsed: collapsed,
                    location: location,
                  ),
                ],
              ],
            ),
          ),
          _LogoutTile(collapsed: collapsed),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

List<Widget> _buildSection(
  BuildContext context,
  WidgetRef ref, {
  required AdminNavSection section,
  required bool collapsed,
  required String location,
}) {
  final checker = ref.watch(permissionCheckerProvider);
  final visible = section.items.where((item) {
    if (item.permission == null) return true;
    return checker.can(item.permission!);
  }).toList();
  if (visible.isEmpty) return const [];

  return [
    if (!collapsed)
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
        child: Text(
          section.label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white54,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    for (final item in visible)
      _NavTile(
        item: item,
        collapsed: collapsed,
        selected: location == item.route ||
            (item.route != '/' && location.startsWith(item.route)),
      ),
  ];
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({required this.collapsed, required this.title});

  final bool collapsed;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 16),
      alignment: collapsed ? Alignment.center : Alignment.centerLeft,
      child: collapsed
          ? Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AdminColors.primaryBlue, AdminColors.gold],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Text(
                'C',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AdminColors.primaryBlue, AdminColors.gold],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'CF',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CrickFlow',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _NavTile extends ConsumerWidget {
  const _NavTile({
    required this.item,
    required this.collapsed,
    required this.selected,
  });

  final AdminNavItem item;
  final bool collapsed;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.adminColors;
    final fg = selected ? AdminColors.gold : Colors.white70;

    return Tooltip(
      message: collapsed ? item.label : '',
      waitDuration: const Duration(milliseconds: 400),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: selected ? colors.sidebarHover : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: item.enabled
                ? () => context.go(item.route)
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${item.label} — coming soon'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 44,
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 12),
              alignment: collapsed ? Alignment.center : Alignment.centerLeft,
              child: collapsed
                  ? Icon(item.icon, color: fg, size: 20)
                  : Row(
                      children: [
                        Icon(item.icon, color: fg, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              color: fg,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        if (!item.enabled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Soon',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoutTile extends ConsumerWidget {
  const _LogoutTile({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Sign out'),
                content: const Text('Sign out of the CrickFlow admin panel?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            );
            if (ok == true) {
              await ref.read(authServiceProvider).signOut();
            }
          },
          child: SizedBox(
            height: 44,
            child: collapsed
                ? const Icon(Icons.logout, color: Colors.white54, size: 20)
                : const Row(
                    children: [
                      SizedBox(width: 12),
                      Icon(Icons.logout, color: Colors.white54, size: 20),
                      SizedBox(width: 12),
                      Text(
                        'Logout',
                        style: TextStyle(color: Colors.white70, fontSize: 13.5),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
