import 'package:flutter/material.dart';

import 'admin_permission.dart';

/// Sidebar section grouping.
enum NavSectionId {
  dashboard,
  management,
  community,
  platform,
  system,
  settings,
}

extension NavSectionIdX on NavSectionId {
  String get label => switch (this) {
        NavSectionId.dashboard => 'Dashboard',
        NavSectionId.management => 'Management',
        NavSectionId.community => 'Community',
        NavSectionId.platform => 'Platform',
        NavSectionId.system => 'System',
        NavSectionId.settings => 'Settings',
      };
}

class AdminNavItem {
  const AdminNavItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.route,
    this.permission,
    this.enabled = true,
  });

  final String id;
  final String label;
  final IconData icon;
  final String route;

  /// If set, item is shown only when the user has this permission.
  final AdminPermission? permission;

  /// When false, shows as coming soon / disabled placeholder.
  final bool enabled;
}

class AdminNavSection {
  const AdminNavSection({
    required this.id,
    required this.items,
  });

  final NavSectionId id;
  final List<AdminNavItem> items;

  String get label => id.label;
}
