/// Khối Điều dưỡng – KTV – Hộ sinh – Thư ký y khoa – Y sĩ
/// + Dược sĩ chỉ khoa YHCT; Nhân viên khoa YHCT hoặc Khoa khám bệnh
/// (đồng bộ backend [NursingBlockClassifier] / frontend `nursingBlock.ts`).
library;

final _blockPattern = RegExp(
  r'dieu\s*duong|\bdd\b|ho\s*sinh|ky\s*thuat\s*vien|\bktv\b|y\s*ta|\bnurse\b'
  r'|thu\s*ky\s*y\s*khoa|thu\s*ky\s*ykhoa|medical\s*secretar|midwife|technici'
  r'|\by\s*s[iy]\b|assistant\s*physician|physician\s*assistant',
);
final _pharmacistPattern = RegExp(r'duoc\s*si|\bduocsy\b|pharmacist');
final _staffPattern = RegExp(r'\bnhan\s*vien\b');
final _yhctDeptPattern = RegExp(r'y\s*hoc\s*co\s*truyen|\byhct\b');
final _outpatientDeptPattern = RegExp(r'khoa\s*kham\s*benh|^kham\s*benh$');
final _excludedNursingHeadDept = RegExp(
  r'ke\s*hoach\s*tong\s*hop|kinh\s*doanh|phat\s*trien|^phong\s+dieu\s+duong$',
);

/// Bảng bỏ dấu tiếng Việt (precomposed) — không phụ thuộc NFD.
const _vietMap = <String, String>{
  'à': 'a', 'á': 'a', 'ạ': 'a', 'ả': 'a', 'ã': 'a',
  'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ậ': 'a', 'ẩ': 'a', 'ẫ': 'a',
  'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ặ': 'a', 'ẳ': 'a', 'ẵ': 'a',
  'è': 'e', 'é': 'e', 'ẹ': 'e', 'ẻ': 'e', 'ẽ': 'e',
  'ê': 'e', 'ề': 'e', 'ế': 'e', 'ệ': 'e', 'ể': 'e', 'ễ': 'e',
  'ì': 'i', 'í': 'i', 'ị': 'i', 'ỉ': 'i', 'ĩ': 'i',
  'ò': 'o', 'ó': 'o', 'ọ': 'o', 'ỏ': 'o', 'õ': 'o',
  'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ộ': 'o', 'ổ': 'o', 'ỗ': 'o',
  'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ợ': 'o', 'ở': 'o', 'ỡ': 'o',
  'ù': 'u', 'ú': 'u', 'ụ': 'u', 'ủ': 'u', 'ũ': 'u',
  'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ự': 'u', 'ử': 'u', 'ữ': 'u',
  'ỳ': 'y', 'ý': 'y', 'ỵ': 'y', 'ỷ': 'y', 'ỹ': 'y',
  'đ': 'd',
};

String normalizeVi(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final lower = raw.toLowerCase();
  final buf = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    if (rune >= 0x0300 && rune <= 0x036F) continue;
    buf.write(_vietMap[ch] ?? ch);
  }
  return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool _isExcludedNursingHeadDepartment(String? departmentName) {
  final dept = normalizeVi(departmentName);
  return dept.isNotEmpty && _excludedNursingHeadDept.hasMatch(dept);
}

bool _isYhct(String? departmentName) {
  final dept = normalizeVi(departmentName);
  return dept.isNotEmpty && _yhctDeptPattern.hasMatch(dept);
}

bool _isOutpatient(String? departmentName) {
  final dept = normalizeVi(departmentName);
  return dept.isNotEmpty && _outpatientDeptPattern.hasMatch(dept);
}

bool _isStaffEligibleDept(String? departmentName) =>
    _isYhct(departmentName) || _isOutpatient(departmentName);

/// True nếu thuộc phạm vi Trưởng phòng ĐD / khối đánh giá ĐD.
bool isNursingBlockTitle(String? positionTitle, [String? departmentName]) {
  if (_isExcludedNursingHeadDepartment(departmentName)) return false;
  final title = normalizeVi(positionTitle);
  if (title.isEmpty) return false;
  if (_blockPattern.hasMatch(title)) return true;
  if (_staffPattern.hasMatch(title) && _isStaffEligibleDept(departmentName)) {
    return true;
  }
  return _pharmacistPattern.hasMatch(title) && _isYhct(departmentName);
}

bool isNursingHeadStageLabel(String label) {
  final n = normalizeVi(label);
  return n.contains('truong phong dd') ||
      n.contains('truong phong dieu duong') ||
      n.contains('dieu duong truong');
}

/// Lọc bước «Trưởng phòng ĐD» khỏi luồng hiển thị nếu không thuộc khối ĐD.
List<String> filterDisplayStages(
  Iterable<String> stages, {
  required String? positionTitle,
  String? departmentName,
}) {
  final nursing = isNursingBlockTitle(positionTitle, departmentName);
  return [
    for (final s in stages)
      if (nursing || !isNursingHeadStageLabel(s)) s,
  ];
}

List<String> attendanceFlowLabels(
  String? positionTitle, [
  String? departmentName,
]) {
  if (isNursingBlockTitle(positionTitle, departmentName)) {
    return const [
      'Trưởng khoa/phòng',
      'Trưởng phòng ĐD',
      'HCNS',
      'Giám đốc',
    ];
  }
  return const [
    'Trưởng khoa/phòng',
    'HCNS',
    'Giám đốc',
  ];
}

List<String> deploymentFlowLabels(
  String? positionTitle, [
  String? departmentName,
]) {
  if (isNursingBlockTitle(positionTitle, departmentName)) {
    return const [
      'Trưởng khoa/phòng',
      'Trưởng phòng ĐD',
      'HCNS',
      'Giám đốc',
    ];
  }
  return const [
    'Trưởng khoa/phòng',
    'HCNS',
    'Giám đốc',
  ];
}

List<String> probationFlowLabels(
  String? positionTitle, [
  String? departmentName,
]) {
  if (isNursingBlockTitle(positionTitle, departmentName)) {
    return const [
      'Trưởng phòng ĐD',
      'HCNS',
      'Giám đốc',
    ];
  }
  return const [
    'HCNS',
    'Giám đốc',
  ];
}

List<String> mainDutyFlowLabels(
  String? positionTitle, [
  String? departmentName,
]) {
  if (isNursingBlockTitle(positionTitle, departmentName)) {
    return const [
      'Trưởng phòng ĐD',
      'Giám đốc',
    ];
  }
  return const [
    'Trưởng khoa/phòng',
    'Giám đốc',
  ];
}

List<String> flowLabelsForRequestType(
  String typeKey,
  Iterable<String> configStageLabels,
  String? positionTitle, [
  String? departmentName,
]) {
  return switch (typeKey) {
    'probation-conversion' => probationFlowLabels(positionTitle, departmentName),
    'main-duty-authorization' =>
      mainDutyFlowLabels(positionTitle, departmentName),
    _ => filterDisplayStages(
        configStageLabels,
        positionTitle: positionTitle,
        departmentName: departmentName,
      ),
  };
}
