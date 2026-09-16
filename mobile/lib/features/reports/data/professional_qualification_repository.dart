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

  /// Khối chứng chỉ hành nghề; `null` khi backend cũ chưa trả.
  PracticeCertificateReport? get practiceCertificate {
    final m = raw['practiceCertificate'];
    if (m is! Map) return null;
    return PracticeCertificateReport(raw: Map<String, dynamic>.from(m));
  }
}

/// Chứng chỉ / giấy phép hành nghề của 6 đối tượng nghề nghiệp.
///
/// Giấy phép cấp từ 01/01/2024 có hạn 5 năm; chứng chỉ cấp trước đó backend
/// ghi nhận là không thời hạn nên không sinh cảnh báo hết hạn.
class PracticeCertificateReport {
  PracticeCertificateReport({required this.raw});
  final Map<String, dynamic> raw;

  Map<String, dynamic> get _kpi {
    final m = raw['kpi'];
    return m is Map ? Map<String, dynamic>.from(m) : const {};
  }

  int _k(String key) => (_kpi[key] as num?)?.toInt() ?? 0;

  int get total => _k('total');
  int get withCert => _k('withCert');
  int get missing => _k('missing');
  double get coveragePercent =>
      (_kpi['coveragePercent'] as num?)?.toDouble() ?? 0;
  int get noDate => _k('noDate');
  int get unlimited => _k('unlimited');
  int get valid => _k('valid');
  int get expiringSoon => _k('expiringSoon');
  int get expired => _k('expired');
  int get needsAttention => _k('needsAttention');

  List<Map<String, dynamic>> _list(String key) {
    final list = raw[key];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<Map<String, dynamic>> get byStatus => _list('byStatus');
  List<Map<String, dynamic>> get byProfession => _list('byProfession');
  List<Map<String, dynamic>> get byDepartment => _list('byDepartment');
  List<Map<String, dynamic>> get byScope => _list('byScope');

  List<PracticeCertificateDetail> get details =>
      _list('details').map(PracticeCertificateDetail.new).toList();
}

class PracticeCertificateDetail {
  PracticeCertificateDetail(this.raw);
  final Map<String, dynamic> raw;

  String _s(String key) => raw[key]?.toString().trim() ?? '';

  int get employeeId => (raw['employeeId'] as num?)?.toInt() ?? 0;
  String get fullName => _s('fullName');
  String get employeeCode => _s('employeeCode');
  String get departmentName => _s('departmentName');
  String get professionLabel => _s('professionLabel');
  String get professionCode => _s('professionCode');
  String get certNumber => _s('certNumber');
  String get certDateRaw => _s('certDateRaw');
  String get issueDateLabel => _s('issueDateLabel');
  String get expiryDateLabel => _s('expiryDateLabel');
  int? get daysToExpiry => (raw['daysToExpiry'] as num?)?.toInt();
  String get scope => _s('scope');
  String get statusCode => _s('certStatusCode');
  String get statusLabel => _s('certStatusLabel');
  bool get needsAttention => raw['needsAttention'] == true;
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
