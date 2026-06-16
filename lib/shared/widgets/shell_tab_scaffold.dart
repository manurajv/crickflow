import 'package:flutter/material.dart';
import 'cf_app_drawer.dart';
import 'cf_chrome_app_bar.dart';

/// Tab root scaffold with side drawer + hamburger menu.
class ShellTabScaffold extends StatelessWidget {
  const ShellTabScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottom,
    this.showDrawerMenu = true,
  });

  final Widget title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? bottom;
  final bool showDrawerMenu;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const CfAppDrawer(),
      appBar: CfChromeAppBar(
        title: title,
        actions: actions,
        bottom: bottom,
        showDrawerMenu: showDrawerMenu,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
