import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class ProfessionBlock {
  ProfessionBlock({required this.raw});
  final Map<String, dynamic> raw;

  String get code => raw['code'] as String? ?? '';
  String get label => raw['label'] as String? ?? code;
  int get total => (raw['total'] as num?)?.toInt() ?? 0;
  int get withDegree => (raw['withDegree'] as num?)?.toInt() ?? 0;
  int get missingDegree => (raw['missingDegree'] as num?)?.toInt() ?? 0;
  double get missingPercent => (raw['missingPercent'] as num?)?.toDouble() ?? 0;

  List<Map<String, dynamic>> get byDegreeLevel {
    final list = raw['byDegreeLevel'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<Map<String, dynamic>> get byDepartment {
    final list = raw['byDepartment'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}

class ProfessionalQualificationReport {
  ProfessionalQualificationReport({required this.raw});
  final Map<String, dynamic> raw;

  String get generatedAtLabel =>
      raw['generatedAtLabel'] as String? ?? raw['generatedAt'] as String? ?? '';
  int get totalHospitalStaff =>
      (raw['totalHospitalStaff'] as num?)?.toInt() ?? 0;
  int get totalInScope => (raw['totalInScope'] as num?)?.toInt() ?? 0;
  int get missingDegreeCount =>
      (raw['missingDegreeCount'] as num?)?.toInt() ?? 0;
  int get withDegreeCount => (raw['withDegreeCount'] as num?)?.toInt() ?? 0;

  List<ProfessionBlock> get byProfession {
    final list = raw['byProfession'];
    if (list is! List) return const [];
    return [
      for (final item in list)
        if (item is Map) ProfessionBlock(raw: Map<String, dynamic>.from(item)),
    ];
  }
}

class ProfessionalQualificationRepository {
  ProfessionalQualificationRepository(this._client);
  final ApiClient _client;

  Future<ProfessionalQualificationReport> overview() async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/professional-qualification-reports',
    );
    return ProfessionalQualificationReport(raw: res.data ?? const {});
  }
}

final professionalQualificationRepositoryProvider =
    Provider<ProfessionalQualificationRepository>((ref) {
      return ProfessionalQualificationRepository(ref.watch(apiClientProvider));
    });
