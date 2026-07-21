import 'dart:io';
import 'dart:ui' show Color;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/tournament_notification_types.dart';
import '../../core/constants/team_notification_types.dart';
import '../../core/navigation/notification_navigation.dart';

/// Displays FCM pushes in the tray and routes taps to the correct screen.
class PushNotificationHandler {
  PushNotificationHandler._();

  static final PushNotificationHandler instance = PushNotificationHandler._();

  static const _joinRequestChannelId = 'team_join_requests';
  static const _defaultChannelId = 'crickflow_default';
  static const _goldAccent = 0xFFFFC107;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  GoRouter? _router;
  var _initialized = false;

  void attachRouter(GoRouter router) {
    _router = router;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    if (Platform.isAndroid) {
      const joinChannel = AndroidNotificationChannel(
        _joinRequestChannelId,
        'Team join requests',
        description: 'Alerts when a player requests to join your team',
        importance: Importance.high,
      );
      const defaultChannel = AndroidNotificationChannel(
        _defaultChannelId,
        'CrickFlow',
        description: 'General CrickFlow notifications',
        importance: Importance.defaultImportance,
      );

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(joinChannel);
      await androidPlugin?.createNotificationChannel(defaultChannel);
    }

    _initialized = true;
    _listenForForegroundMessages();
  }

  Future<void> ensurePermissions() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (Platform.isAndroid) {
        await Permission.notification.request();
      }
    } catch (e) {
      debugPrint('Push permission request failed: $e');
    }
  }

  Future<void> handleInitialMessage() async {
    final message = await FirebaseMessaging.instance.getInitialMessage();
    if (message != null) {
      navigateFromData(NotificationNavigation.dataFromRemote(message.data));
    }
  }

  void listenForOpenedMessages() {
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      navigateFromData(NotificationNavigation.dataFromRemote(message.data));
    });
  }

  void navigateFromData(Map<String, String> data) {
    final type = data['type'] ?? '';
    if (type == TournamentNotificationTypes.invitation ||
        type == TeamNotificationTypes.invitation ||
        type == TournamentNotificationTypes.officialInvitation) {
      _router?.push('/notifications');
      return;
    }
    final route = NotificationNavigation.routeFor(
      type: data['type'],
      teamId: data['teamId'],
      matchId: data['matchId'],
      tournamentId: data['tournamentId'],
      playerId: data['playerId'],
      tab: data['tab'],
      requestId: data['requestId'],
    );
    if (route == null) {
      _router?.push('/notifications');
      return;
    }
    _router?.push(route);
  }

  void _onLocalNotificationTapped(NotificationResponse response) {
    final data = NotificationNavigation.decodePayload(response.payload);
    navigateFromData(data);
  }

  void _listenForForegroundMessages() {
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (!_initialized) await initialize();

    final notification = message.notification;
    if (notification == null) return;

    final data = NotificationNavigation.dataFromRemote(message.data);
    final type = data['type'] ?? '';
    final isJoinRequest = type == 'team_join_request';
    final channelId =
        isJoinRequest ? _joinRequestChannelId : _defaultChannelId;
    final title = notification.title ?? 'CrickFlow';
    final body = notification.body ?? '';

    final androidDetails = AndroidNotificationDetails(
      channelId,
      isJoinRequest ? 'Team join requests' : 'CrickFlow',
      channelDescription: isJoinRequest
          ? 'Alerts when a player requests to join your team'
          : 'General CrickFlow notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: const Color(_goldAccent),
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: isJoinRequest ? 'Tap to review request' : 'CrickFlow',
      ),
      category: isJoinRequest
          ? AndroidNotificationCategory.social
          : AndroidNotificationCategory.message,
      ticker: isJoinRequest ? 'New team join request' : title,
    );

    await _localNotifications.show(
      notification.hashCode,
      title,
      body,
      NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          subtitle: isJoinRequest ? 'Tap to review request' : null,
        ),
      ),
      payload: NotificationNavigation.encodePayload(data),
    );
  }
}
