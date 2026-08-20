import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/app_notification.dart';

class NotificationRepository {
  NotificationRepository(this._client);
  final ApiClient _client;

  Future<List<AppNotification>> fetchMine() async {
    final response = await _client.get<List<dynamic>>('/v1/notifications');
    return (response.data ?? [])
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> fetchUnreadCount() async {
    final response = await _client.get<Map<String, dynamic>>('/v1/notifications/unread-count');
    return (response.data?['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(int id) async {
    await _client.patch('/v1/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _client.patch('/v1/notifications/read-all');
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(apiClientProvider));
});
