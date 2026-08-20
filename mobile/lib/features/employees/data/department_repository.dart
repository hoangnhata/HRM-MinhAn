import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/department.dart';

class DepartmentRepository {
  DepartmentRepository(this._client);
  final ApiClient _client;

  Future<List<Department>> list() async {
    final response = await _client.get<List<dynamic>>('/v1/departments');
    return (response.data ?? [])
        .map((e) => Department.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<WorkUnit>> listWorkUnits(int departmentId) async {
    final response = await _client.get<List<dynamic>>(
      '/v1/departments/$departmentId/work-units',
    );
    return (response.data ?? [])
        .map((e) => WorkUnit.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<JobPosition>> listPositions() async {
    final response = await _client.get<List<dynamic>>('/v1/positions');
    final list = (response.data ?? [])
        .whereType<Map>()
        .map((e) => JobPosition.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return list;
  }
}

final departmentRepositoryProvider = Provider<DepartmentRepository>((ref) {
  return DepartmentRepository(ref.watch(apiClientProvider));
});

final departmentListProvider =
    FutureProvider.autoDispose<List<Department>>((ref) {
  return ref.watch(departmentRepositoryProvider).list();
});

final departmentWorkUnitsProvider =
    FutureProvider.autoDispose.family<List<WorkUnit>, int>((ref, departmentId) {
  return ref.watch(departmentRepositoryProvider).listWorkUnits(departmentId);
});

class JobPosition {
  const JobPosition({required this.id, required this.title});

  final int id;
  final String title;

  factory JobPosition.fromJson(Map<String, dynamic> json) {
    return JobPosition(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? 'Chức vụ',
    );
  }
}

final positionListProvider =
    FutureProvider.autoDispose<List<JobPosition>>((ref) {
  return ref.watch(departmentRepositoryProvider).listPositions();
});
