import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'request_type_config.dart';

/// Repository generic dung chung cho 7 loai don tu "khac" — moi loai chi
/// khac nhau ve basePath/stages (khai bao trong RequestTypeConfig), phan
/// logic goi API giong nhau nen dung 1 lop duy nhat de de bao tri.
class GenericRequestRepository {
  GenericRequestRepository(this._client);
  final ApiClient _client;

  String _url(RequestTypeConfig config, String suffix) => '/v1${config.basePath}/$suffix';

  Future<List<Map<String, dynamic>>> related(RequestTypeConfig config) async {
    final response = await _client.get<List<dynamic>>(_url(config, config.relatedPath));
    return (response.data ?? []).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> pendingForStage(RequestTypeConfig config, RequestReviewStage stage) async {
    final response = await _client.get<List<dynamic>>(_url(config, stage.pendingPath));
    return (response.data ?? []).cast<Map<String, dynamic>>();
  }

  /// Tải một đơn theo id — dùng khi mở sâu từ thông báo, lúc đơn không nằm
  /// trong các danh sách đã tải sẵn.
  Future<Map<String, dynamic>> byId(RequestTypeConfig config, int id) async {
    final response = await _client.get<Map<String, dynamic>>(
      _url(config, '$id'),
    );
    return response.data ?? const {};
  }

  Future<List<Map<String, dynamic>>> history(RequestTypeConfig config) async {
    final response = await _client.get<List<dynamic>>(_url(config, config.historyPath));
    return (response.data ?? []).cast<Map<String, dynamic>>();
  }

  /// [extra] là các trường bắt buộc riêng của từng bước duyệt (VD: HCNS duyệt
  /// đào tạo phải gửi `monthlySupport`, `postCourseCommitment`).
  Future<void> review(
    RequestTypeConfig config,
    int id,
    String reviewSlug, {
    required bool approved,
    String? comment,
    Map<String, dynamic> extra = const {},
  }) async {
    await _client.post(
      _url(config, '$id/$reviewSlug'),
      data: {
        'approved': approved,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
        ...extra,
      },
    );
  }

  Future<void> cancel(RequestTypeConfig config, int id) async {
    await _client.post(_url(config, '$id/${config.cancelPath}'));
  }

  Future<Map<String, dynamic>> update(
    RequestTypeConfig config,
    int id,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.put<Map<String, dynamic>>(
      _url(config, '$id'),
      data: body,
    );
    return response.data ?? const {};
  }

  /// Mẫu đánh giá lên chính thức theo hồ sơ NV (`GET /form-type/{id}`).
  Future<Map<String, dynamic>> probationFormType(int employeeId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/v1/probation-conversions/form-type/$employeeId',
    );
    return response.data ?? const {};
  }

  /// Tạo phiếu mới — body khớp web / DTO backend.
  Future<Map<String, dynamic>> create(
    RequestTypeConfig config,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/v1${config.basePath}',
      data: body,
    );
    return response.data ?? const {};
  }
}

final genericRequestRepositoryProvider = Provider<GenericRequestRepository>((ref) {
  return GenericRequestRepository(ref.watch(apiClientProvider));
});
