import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/routes/app_router.dart';
import 'core/constants/app_constants.dart';
import 'core/routing/deep_link_handler.dart';
import 'core/theme/app_theme.dart';
import 'shared/providers/theme_provider.dart';
import 'shared/widgets/fcm_registration_listener.dart';

class CrickFlowApp extends ConsumerStatefulWidget {
  const CrickFlowApp({super.key});

  @override
  ConsumerState<CrickFlowApp> createState() => _CrickFlowAppState();
}

class _CrickFlowAppState extends ConsumerState<CrickFlowApp> {
  DeepLinkHandler? _deepLinkHandler;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final router = ref.read(routerProvider);
      _deepLinkHandler = DeepLinkHandler(router);
      _deepLinkHandler!.init();
    });
  }

  @override
  void dispose() {
    _deepLinkHandler?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) => FcmRegistrationListener(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
