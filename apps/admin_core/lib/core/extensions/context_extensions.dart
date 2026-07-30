import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';
import '../theme/admin_dimens.dart';

extension AdminContextX on BuildContext {
  AdminColors get adminColors =>
      Theme.of(this).extension<AdminColors>() ?? AdminColors.light;

  AdminDimens get adminDimens =>
      Theme.of(this).extension<AdminDimens>() ?? AdminDimens.standard;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  double get screenWidth => MediaQuery.sizeOf(this).width;

  bool get isTablet => screenWidth >= 900 && screenWidth < 1200;
  bool get isLaptop => screenWidth >= 1200 && screenWidth < 1440;
  bool get isDesktop => screenWidth >= 1440;
  bool get isWide => screenWidth >= 1800;
}
