import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Đồng bộ số đỏ trên icon app (home screen) với số thông báo chưa đọc.
///
/// iOS: UNUserNotificationCenter badge (giống ERP trên TestFlight).
/// Android: chỉ một số launcher hỗ trợ; push FCM vẫn gửi notificationCount.
class AppIconBadge {
  AppIconBadge._();

  static const _channel = MethodChannel('com.minhan.hrm/app_badge');

  static Future<void> sync(int unreadCount) async {
    final count = unreadCount < 0 ? 0 : unreadCount;
    try {
      if (Platform.isIOS) {
        await _channel.invokeMethod<void>('setBadge', count);
      } else if (Platform.isAndroid) {
        // Launcher Android không thống nhất — vẫn thử; thất bại thì bỏ qua.
        await _channel.invokeMethod<void>('setBadge', count);
      }
    } catch (e) {
      debugPrint('AppIconBadge: $e');
    }
  }

  static Future<void> clear() => sync(0);
}
