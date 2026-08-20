import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class EmployeeDocumentMeta {
  const EmployeeDocumentMeta({
    required this.id,
    required this.originalName,
    required this.docType,
    this.createdAt,
  });

  final int id;
  final String originalName;
  final String docType;
  final String? createdAt;

  factory EmployeeDocumentMeta.fromJson(Map<String, dynamic> json) {
    return EmployeeDocumentMeta(
      id: (json['id'] as num).toInt(),
      originalName: json['originalName'] as String? ?? 'Tệp PDF',
      docType: json['docType'] as String? ?? 'PDF',
      createdAt: json['createdAt']?.toString(),
    );
  }
}

class EmployeeDocumentRepository {
  EmployeeDocumentRepository(this._client);
  final ApiClient _client;

  Future<List<EmployeeDocumentMeta>> listForEmployee(int employeeId) async {
    final response = await _client.get<List<dynamic>>(
      '/v1/documents/employees/$employeeId',
    );
    final raw = response.data ?? const [];
    return raw
        .whereType<Map>()
        .map((e) => EmployeeDocumentMeta.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}

final employeeDocumentRepositoryProvider =
    Provider<EmployeeDocumentRepository>((ref) {
  return EmployeeDocumentRepository(ref.watch(apiClientProvider));
});

final employeeDocumentsProvider = FutureProvider.autoDispose
    .family<List<EmployeeDocumentMeta>, int>((ref, employeeId) async {
  try {
    return await ref
        .watch(employeeDocumentRepositoryProvider)
        .listForEmployee(employeeId);
  } catch (_) {
    return const [];
  }
});
