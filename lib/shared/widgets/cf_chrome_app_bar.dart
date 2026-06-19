import 'package:flutter/material.dart';
import '../../core/theme/cf_colors.dart';
import '../../core/theme/app_dimens.dart';

/// Branded app bar — matches bottom navigation chrome (surface + border).
class CfChromeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CfChromeAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.bottom,
    this.centerTitle = true,
    this.showDrawerMenu = false,
  });

  final Widget title;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;
  final bool showDrawerMenu;

  @override
  Size get preferredSize => Size.fromHeight(
        AppDimens.appBarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: leading ??
          (showDrawerMenu
              ? Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu),
                    tooltip: 'Menu',
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                )
              : null),
      automaticallyImplyLeading: !showDrawerMenu,
      title: title,
      centerTitle: centerTitle,
      actions: actions,
      bottom: bottom,
      flexibleSpace: DecoratedBox(
        decoration: BoxDecoration(gradient: context.cf.appBarGradient),
      ),
    );
  }
}
