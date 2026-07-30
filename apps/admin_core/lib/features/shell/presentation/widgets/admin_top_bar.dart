import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/a11y/admin_a11y.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/locale/admin_locale_catalog.dart';
import '../../../../core/locale/admin_locale_providers.dart';
import '../../../../core/router/admin_route_paths.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../../shared/widgets/cf_snackbar.dart';
import '../../../audit/providers/audit_providers.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../users/models/admin_audit_log.dart';
import '../../providers/shell_providers.dart';

class AdminTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const AdminTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.adminColors;
    final dimens = context.adminDimens;
    final l10n = context.l10n;
    final crumbs = ref.watch(breadcrumbProvider);
    final collapsed = ref.watch(sidebarCollapsedProvider);
    final session = ref.watch(adminSessionProvider);
    final admin = session.adminUser;

    return Material(
      color: colors.surface,
      elevation: 0,
      child: Container(
        height: dimens.topBarHeight,
        padding: EdgeInsets.symmetric(horizontal: dimens.spaceLg),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.border)),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip:
                  collapsed ? l10n.actionExpandNav : l10n.actionCollapseNav,
              onPressed: () {
                ref.read(sidebarCollapsedProvider.notifier).state = !collapsed;
              },
              icon: const Icon(Icons.menu),
            ),
            SizedBox(width: dimens.spaceSm),
            Expanded(child: _Breadcrumbs(crumbs: crumbs)),
            IconButton(
              tooltip: l10n.navNotifications,
              onPressed: () {
                CfSnack.info(context, l10n.commonNotificationsNone);
              },
              icon: const Icon(Icons.notifications_outlined),
            ),
            SizedBox(width: dimens.spaceXs),
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
    final dimens = context.adminDimens;
    final l10n = context.l10n;
    if (crumbs.isEmpty) {
      return Text(
        l10n.breadcrumbDashboard,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
      );
    }
    return Semantics(
      label: 'Breadcrumb: ${crumbs.join(' > ')}',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < crumbs.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: dimens.spaceSm),
                  child: Icon(
                    Icons.chevron_right,
                    size: dimens.iconSm,
                    color: colors.textMuted,
                  ),
                ),
              Text(
                crumbs[i],
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: i == crumbs.length - 1
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: i == crumbs.length - 1
                          ? colors.textPrimary
                          : colors.textSecondary,
                    ),
              ),
            ],
          ],
        ),
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
    final dimens = context.adminDimens;
    final l10n = context.l10n;
    final regional = ref.watch(adminRegionalSettingsProvider);

    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: dimens.borderRadiusMd),
      tooltip: l10n.accountMenu,
      onSelected: (value) async {
        if (value == 'profile') {
          context.go(AdminRoutePaths.profile);
        } else if (value == 'settings') {
          context.go(AdminRoutePaths.accountSettings);
        } else if (value == 'theme') {
          ref.read(themeModeProvider.notifier).state =
              isDark ? ThemeMode.light : ThemeMode.dark;
        } else if (value.startsWith('lang:')) {
          final code = value.substring(5);
          await ref
              .read(adminRegionalSettingsProvider.notifier)
              .setLanguageCode(code == 'system' ? null : code);
          if (context.mounted) {
            CfSnack.info(context, l10n.accountLanguageSaved);
          }
        } else if (value == 'logout') {
          final session = ref.read(adminSessionProvider);
          final admin = session.adminUser;
          final user = ref.read(authServiceProvider).currentUser;
          await ref.read(authServiceProvider).signOut();
          if (admin != null || user != null) {
            await ref.read(auditLoggerProvider).logAuthEvent(
                  action: AdminAuditActions.adminLogout,
                  uid: admin?.uid ?? user?.uid ?? 'unknown',
                  email: admin?.email ?? user?.email ?? '',
                  roleId: admin?.roleId,
                  organizationId: admin?.organizationId,
                );
          }
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
        PopupMenuItem(
          value: 'profile',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: Text(l10n.accountProfile),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'settings',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.manage_accounts_outlined),
            title: Text(l10n.accountSettings),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'theme',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            title: Text(isDark ? l10n.accountLightMode : l10n.accountDarkMode),
            dense: true,
          ),
        ),
        PopupMenuItem(
          enabled: false,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.language_outlined),
            title: Text(l10n.accountLanguage),
            dense: true,
          ),
        ),
        for (final opt in AdminLocaleCatalog.selectable)
          PopupMenuItem(
            value: 'lang:${opt.code ?? 'system'}',
            child: ListTile(
              contentPadding: const EdgeInsets.only(left: 24),
              leading: Icon(
                (regional.languageCode ?? 'system') == (opt.code ?? 'system')
                    ? Icons.check
                    : Icons.translate_outlined,
                size: 18,
              ),
              title: Text(opt.nativeName),
              subtitle: Text(opt.englishName),
              dense: true,
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout),
            title: Text(l10n.actionLogout),
            dense: true,
          ),
        ),
      ],
      child: Row(
        children: [
          _ProfileAvatar(photoUrl: photoUrl, initials: initials),
          SizedBox(width: dimens.spaceSm),
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
          Icon(Icons.keyboard_arrow_down, size: dimens.iconMd),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.initials,
    this.photoUrl,
  });

  final String initials;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = Text(
      initials,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );

    if (photoUrl == null || photoUrl!.isEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: AdminColors.primaryBlue,
        child: fallback,
      );
    }

    return CircleAvatar(
      radius: 16,
      backgroundColor: AdminColors.primaryBlue,
      child: ClipOval(
        child: Image.network(
          photoUrl!,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Center(child: fallback),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Center(child: fallback);
          },
        ),
      ),
    );
  }
}
