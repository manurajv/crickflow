import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/routes/app_router.dart';
import '../providers/providers.dart';
import '../../data/services/push_notification_handler.dart';

/// Registers FCM token and routes notification taps to the correct screen.
class FcmRegistrationListener extends ConsumerStatefulWidget {
  const FcmRegistrationListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FcmRegistrationListener> createState() =>
      _FcmRegistrationListenerState();
}

class _FcmRegistrationListenerState
    extends ConsumerState<FcmRegistrationListener> {
  String? _listeningForUid;
  var _pushInitialized = false;
  var _routerAttached = false;

  Future<void> _ensurePushReady() async {
    if (_pushInitialized) return;
    _pushInitialized = true;
    await ref.read(notificationServiceProvider).initializePush();
  }

  void _attachRouterAndInitialMessage() {
    if (_routerAttached) return;
    _routerAttached = true;
    PushNotificationHandler.instance.attachRouter(ref.read(routerProvider));
    PushNotificationHandler.instance.handleInitialMessage();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (previous, next) async {
      final uid = next.value?.uid;
      if (uid == null) {
        _listeningForUid = null;
        return;
      }
      await _ensurePushReady();
      _attachRouterAndInitialMessage();
      await ref.read(notificationServiceProvider).registerDevice(uid);
      if (_listeningForUid != uid) {
        _listeningForUid = uid;
        ref.read(notificationServiceProvider).listenForTokenRefresh(uid);
      }
    });

    final uid = ref.watch(authStateProvider).value?.uid;
    if (uid != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _ensurePushReady();
        _attachRouterAndInitialMessage();
        await ref.read(notificationServiceProvider).registerDevice(uid);
      });
    }

    return widget.child;
  }
}
