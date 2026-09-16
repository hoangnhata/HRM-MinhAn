import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/app_notification.dart';

class NotificationRepository {
  NotificationRepository(this._client);
  final ApiClient _client;

  /// Trang đầu dạng danh sách phẳng — giữ cho nơi chỉ cần vài tin mới nhất.
  Future<List<AppNotification>> fetchMine({int limit = pageSize}) async {
    final response = await _client.get<List<dynamic>>(
      '/v1/notifications',
      query: {'limit': limit},
    );
    return (response.data ?? [])
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static const int pageSize = 20;

  /// Một trang thông báo: chưa đọc trước, mới nhất trước.
  ///
  /// Trước đây app kéo toàn bộ lịch sử mỗi 20 giây một lần; tài khoản duyệt
  /// nhiều đơn có hàng nghìn dòng nên vừa chậm vừa tốn pin.
  Future<NotificationPage> fetchPage(int page, {int size = pageSize}) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/v1/notifications/page',
      query: {'page': page, 'size': size},
    );
    final data = response.data ?? const <String, dynamic>{};
    final rawItems = data['items'];
    return NotificationPage(
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (e) => AppNotification.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
          : const [],
      page: (data['page'] as num?)?.toInt() ?? page,
      hasMore: data['hasMore'] == true,
      total: (data['total'] as num?)?.toInt() ?? 0,
      unread: (data['unread'] as num?)?.toInt() ?? 0,
    );
  }

  Future<int> fetchUnreadCount() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/v1/notifications/unread-count',
    );
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

class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.page,
    required this.hasMore,
    required this.total,
    required this.unread,
  });

  final List<AppNotification> items;
  final int page;
  final bool hasMore;
  final int total;
  final int unread;
}
