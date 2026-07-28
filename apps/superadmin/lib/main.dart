import 'package:crickflow_admin_core/crickflow_admin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/firebase_options.dart';
import 'config/nav_config.dart';
import 'config/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapFirebase(DefaultFirebaseOptions.currentPlatform);
  runApp(
    ProviderScope(
      overrides: [
        adminAppTypeProvider.overrideWithValue(AdminAppType.superAdmin),
        navSectionsProvider.overrideWithValue(buildSuperAdminNav()),
      ],
      child: const SuperAdminApp(),
    ),
  );
}

class SuperAdminApp extends ConsumerWidget {
  const SuperAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(_routerProvider);

    return MaterialApp.router(
      title: 'CrickFlow Super Admin',
      debugShowCheckedModeBanner: false,
      theme: AdminTheme.light(),
      darkTheme: AdminTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

final _routerProvider = Provider((ref) => createSuperAdminRouter(ref));
