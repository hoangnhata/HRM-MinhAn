import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/device_token_repository.dart';
import '../presentation/notification_ui.dart';

/// Callback mở màn từ payload FCM (đã resolve sẵn route/tab).
typedef PushOpenHandler = void Function(NotificationTarget target);

/// Gọi khi nhận FCM lúc app đang mở — đồng bộ inbox với web.
typedef PushInboxRefreshHandler = Future<void> Function();

/// Background isolate handler — phải là top-level.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Không có google-services.json / Firebase chưa cấu hình.
  }
}

/// Push FCM + local notification. An toàn khi chưa có Firebase (no-op).
class PushNotificationCoordinator {
  PushNotificationCoordinator(this._ref);

  final Ref _ref;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  String? _currentToken;
  PushOpenHandler? onOpen;
  PushInboxRefreshHandler? onInboxRefresh;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedSub;

  bool get isReady => _ready;

  Future<void> initialize() async {
    if (_ready) return;
    try {
      await Firebase.initializeApp();
    } catch (e, st) {
      debugPrint(
        'FCM: Firebase chưa sẵn sàng ($e). Push tắt cho đến khi cấu hình.',
      );
      debugPrint('$st');
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _local.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        _openFromEncodedPayload(payload);
      },
    );

    if (Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              'hrm_push',
              'Thông báo HRM',
              description: 'Thông báo đơn từ và duyệt của Bệnh viện Minh An',
              importance: Importance.high,
            ),
          );
    }

    if (Platform.isIOS) {
      await _local
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
    );
    debugPrint('FCM permission: ${settings.authorizationStatus}');

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // iOS: phải có APNs token trước khi getToken() ổn định.
    if (Platform.isIOS) {
      for (var i = 0; i < 10; i++) {
        final apns = await messaging.getAPNSToken();
        if (apns != null && apns.isNotEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }

    _onMessageSub = FirebaseMessaging.onMessage.listen(_showForeground);
    _onOpenedSub =
        FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteOpen);

    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleRemoteOpen(initial);
      });
    }

    _ready = true;
  }

  Future<void> syncTokenWithBackend() async {
    if (!_ready) return;
    try {
      if (Platform.isIOS) {
        final apns = await FirebaseMessaging.instance.getAPNSToken();
        if (apns == null || apns.isEmpty) {
          debugPrint('FCM: chưa có APNs token — thử lại sau khi cấp quyền thông báo');
          return;
        }
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _registerToken(token);
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub =
          FirebaseMessaging.instance.onTokenRefresh.listen(_registerToken);
    } catch (e) {
      debugPrint('FCM: không lấy/đăng ký được token: $e');
    }
  }

  Future<void> clearTokenOnLogout() async {
    final token = _currentToken;
    _currentToken = null;
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    if (token == null || token.isEmpty) return;
    try {
      await _ref.read(deviceTokenRepositoryProvider).unregister(token);
    } catch (_) {
      // Logout vẫn tiếp tục dù huỷ token lỗi mạng.
    }
  }

  Future<void> _registerToken(String token) async {
    _currentToken = token;
    final platform = Platform.isIOS ? 'IOS' : 'ANDROID';
    try {
      await _ref.read(deviceTokenRepositoryProvider).register(
            token: token,
            platform: platform,
          );
    } catch (e) {
      debugPrint('FCM: đăng ký token backend thất bại: $e');
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final title = message.notification?.title ??
        message.data['title']?.toString() ??
        'Thông báo';
    final body = message.notification?.body ??
        message.data['body']?.toString() ??
        '';
    await _local.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'hrm_push',
          'Thông báo HRM',
          channelDescription:
              'Thông báo đơn từ và duyệt của Bệnh viện Minh An',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: _encodePayload(message.data),
    );
    // Đồng bộ badge + danh sách với web ngay khi có push.
    try {
      await onInboxRefresh?.call();
    } catch (_) {}
  }

  void _handleRemoteOpen(RemoteMessage message) {
    final target = NotificationUi.resolveFromPushData(
      Map<String, dynamic>.from(message.data),
    );
    onOpen?.call(target);
  }

  void _openFromEncodedPayload(String payload) {
    final data = _decodePayload(payload);
    final target = NotificationUi.resolveFromPushData(data);
    onOpen?.call(target);
  }

  static String _encodePayload(Map<String, dynamic> data) {
    return data.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value?.toString() ?? '')}')
        .join('&');
  }

  static Map<String, dynamic> _decodePayload(String payload) {
    final out = <String, dynamic>{};
    for (final part in payload.split('&')) {
      if (part.isEmpty) continue;
      final i = part.indexOf('=');
      if (i <= 0) continue;
      out[Uri.decodeComponent(part.substring(0, i))] =
          Uri.decodeComponent(part.substring(i + 1));
    }
    return out;
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
    _onMessageSub?.cancel();
    _onOpenedSub?.cancel();
  }
}

final pushNotificationCoordinatorProvider =
    Provider<PushNotificationCoordinator>((ref) {
  final coordinator = PushNotificationCoordinator(ref);
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
