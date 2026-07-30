import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/a11y/admin_a11y.dart';
import '../../../../core/constants/breakpoints.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/l10n/admin_nav_l10n.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/admin_motion.dart';
import '../../../../models/nav_models.dart';
import '../../../../shared/widgets/cf_dialog.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../providers/shell_providers.dart';

/// Width below which the sidebar shows icon-only chrome.
/// Chosen between [Breakpoints.sidebarCollapsed] and expanded so mid-animation
/// frames stay compact until there is room for labels.
const double _sidebarCompactMaxWidth = 140;

class AdminSidebar extends ConsumerWidget {
  const AdminSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collapsed = ref.watch(sidebarCollapsedProvider);
    final sections = ref.watch(navSectionsProvider);
    final appType = ref.watch(adminAppTypeProvider);
    final checker = ref.watch(permissionCheckerProvider);
    final location = GoRouterState.of(context).uri.path;
    final width = collapsed
        ? Breakpoints.sidebarCollapsed
        : Breakpoints.sidebarExpanded;

    final dimens = context.adminDimens;
    return AnimatedContainer(
      duration: AdminMotion.normal,
      curve: AdminMotion.standard,
      width: width,
      clipBehavior: Clip.hardEdge,
      color: context.adminColors.sidebar,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < _sidebarCompactMaxWidth;
          return Column(
            children: [
              _SidebarHeader(
                compact: compact,
                title: appType.displayName,
              ),
              Expanded(
                child: Semantics(
                  label: context.l10n.a11yMainNavigation,
                  container: true,
                  child: ListView(
                    padding: EdgeInsets.symmetric(
                      vertical: dimens.spaceSm,
                      horizontal: dimens.spaceSm,
                    ),
                    children: [
                      for (final section in sections) ...[
                        ..._buildSection(
                          context,
                          checker: checker,
                          section: section,
                          compact: compact,
                          location: location,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              _LogoutTile(compact: compact),
              SizedBox(height: dimens.spaceMd),
            ],
          );
        },
      ),
    );
  }
}

List<Widget> _buildSection(
  BuildContext context, {
  required PermissionChecker checker,
  required AdminNavSection section,
  required bool compact,
  required String location,
}) {
  final visible = section.items.where((item) {
    if (item.permission == null) return true;
    return checker.can(item.permission!);
  }).toList();
  if (visible.isEmpty) return const [];

  final colors = context.adminColors;
  final dimens = context.adminDimens;
  final l10n = context.l10n;
  final sectionLabel = AdminNavL10n.section(l10n, section.id);
  return [
    if (!compact)
      Padding(
        padding: EdgeInsets.fromLTRB(
          dimens.spaceMd,
          dimens.spaceLg,
          dimens.spaceMd,
          dimens.spaceSm - 2,
        ),
        child: Text(
          sectionLabel.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.sidebarFgMuted,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    for (final item in visible)
      _NavTile(
        item: item,
        label: AdminNavL10n.item(l10n, item),
        compact: compact,
        selected: location == item.route ||
            (item.route != '/' && location.startsWith(item.route)),
      ),
  ];
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({required this.compact, required this.title});

  final bool compact;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final dimens = context.adminDimens;
    final mark = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AdminColors.primaryBlue, AdminColors.gold],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        compact ? 'C' : 'CF',
        style: TextStyle(
          color: colors.sidebarFg,
          fontWeight: FontWeight.w800,
          fontSize: compact ? 14 : 12,
        ),
      ),
    );

    return Semantics(
      header: true,
      label: 'CrickFlow $title',
      child: Container(
        height: dimens.topBarHeight,
        padding: EdgeInsets.symmetric(horizontal: compact ? 0 : dimens.spaceLg),
        alignment: compact ? Alignment.center : Alignment.centerLeft,
        child: compact
            ? mark
            : Row(
                children: [
                  mark,
                  SizedBox(width: dimens.spaceMd),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CrickFlow',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.sidebarFg,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.sidebarFgMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _NavTile extends ConsumerWidget {
  const _NavTile({
    required this.item,
    required this.label,
    required this.compact,
    required this.selected,
  });

  final AdminNavItem item;
  final String label;
  final bool compact;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.adminColors;
    final dimens = context.adminDimens;
    final l10n = context.l10n;
    final fg = selected ? colors.sidebarSelected : colors.sidebarFgMuted;
    final radius = dimens.borderRadiusMd;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: compact ? label : '',
        waitDuration: const Duration(milliseconds: 400),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: dimens.spaceXs / 2),
          child: Material(
            color: selected ? colors.sidebarHover : Colors.transparent,
            borderRadius: radius,
            child: InkWell(
              borderRadius: radius,
              hoverColor: colors.sidebarHover.withValues(alpha: 0.85),
              onTap: item.enabled
                  ? () => context.go(item.route)
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$label — ${l10n.commonComingSoon}'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
              child: AnimatedContainer(
                duration: AdminMotion.fast,
                curve: AdminMotion.standard,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: selected
                      ? Border(
                          left: BorderSide(
                            color: colors.sidebarSelected,
                            width: 3,
                          ),
                        )
                      : null,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 0 : dimens.spaceMd,
                ),
                alignment: compact ? Alignment.center : Alignment.centerLeft,
                child: compact
                    ? Icon(item.icon, color: fg, size: 20)
                    : Row(
                        children: [
                          Icon(item.icon, color: fg, size: 20),
                          SizedBox(width: dimens.spaceMd),
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: fg,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          if (!item.enabled)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: dimens.spaceSm - 2,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    colors.sidebarFg.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                l10n.commonComingSoon,
                                style: TextStyle(
                                  color: colors.sidebarFgMuted,
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
      ),
    );
  }
}

class _LogoutTile extends ConsumerWidget {
  const _LogoutTile({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.adminColors;
    final dimens = context.adminDimens;
    final l10n = context.l10n;
    final radius = dimens.borderRadiusMd;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: dimens.spaceSm),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          hoverColor: colors.sidebarHover,
          onTap: () async {
            final ok = await showCfConfirmDialog(
              context: context,
              title: l10n.actionLogout,
              message: l10n.actionLogout,
              confirmLabel: l10n.actionLogout,
              kind: CfDialogKind.warning,
            );
            if (ok == true) {
              await ref.read(authServiceProvider).signOut();
            }
          },
          child: Semantics(
            button: true,
            label: l10n.actionLogout,
            child: SizedBox(
              height: 44,
              child: compact
                  ? Center(
                      child: Icon(
                        Icons.logout,
                        color: colors.sidebarFgMuted,
                        size: 20,
                      ),
                    )
                  : Row(
                      children: [
                        SizedBox(width: dimens.spaceMd),
                        Icon(
                          Icons.logout,
                          color: colors.sidebarFgMuted,
                          size: 20,
                        ),
                        SizedBox(width: dimens.spaceMd),
                        Expanded(
                          child: Text(
                            l10n.actionLogout,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.sidebarFgMuted,
                              fontSize: 13.5,
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
