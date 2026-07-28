import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';

extension AdminContextX on BuildContext {
  AdminColors get adminColors =>
      Theme.of(this).extension<AdminColors>() ?? AdminColors.light;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  double get screenWidth => MediaQuery.sizeOf(this).width;
}
