/// Khối Điều dưỡng – KTV – Hộ sinh – Thư ký y khoa
/// (đồng bộ backend [NursingBlockClassifier] / frontend `nursingBlock.ts`).
library;

final _blockPattern = RegExp(
  r'dieu\s*duong|\bdd\b|ho\s*sinh|ky\s*thuat\s*vien|\bktv\b|y\s*ta|\bnurse\b'
  r'|thu\s*ky\s*y\s*khoa|thu\s*ky\s*ykhoa|medical\s*secretar|midwife|technici',
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

String _normalize(String? positionTitle) {
  if (positionTitle == null || positionTitle.isEmpty) return '';
  final lower = positionTitle.toLowerCase();
  final buf = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    if (rune >= 0x0300 && rune <= 0x036F) continue; // combining marks
    buf.write(_vietMap[ch] ?? ch);
  }
  return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// True nếu chức danh thuộc khối ĐD–KTV–HS–Thư ký y khoa.
bool isNursingBlockTitle(String? positionTitle) {
  final norm = _normalize(positionTitle);
  return norm.isNotEmpty && _blockPattern.hasMatch(norm);
}

bool isNursingHeadStageLabel(String label) {
  final n = _normalize(label);
  return n.contains('truong phong dd') ||
      n.contains('truong phong dieu duong') ||
      n.contains('dieu duong truong');
}

/// Lọc bước «Trưởng phòng ĐD» khỏi luồng hiển thị nếu không thuộc khối ĐD.
List<String> filterDisplayStages(
  Iterable<String> stages, {
  required String? positionTitle,
}) {
  final nursing = isNursingBlockTitle(positionTitle);
  return [
    for (final s in stages)
      if (nursing || !isNursingHeadStageLabel(s)) s,
  ];
}

/// Luồng nghỉ phép / đơn công trên hub.
List<String> attendanceFlowLabels(String? positionTitle) {
  if (isNursingBlockTitle(positionTitle)) {
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

/// Luồng điều động (nhãn hub / intro).
List<String> deploymentFlowLabels(String? positionTitle) {
  if (isNursingBlockTitle(positionTitle)) {
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

/// Luồng lên chính thức.
List<String> probationFlowLabels(String? positionTitle) {
  if (isNursingBlockTitle(positionTitle)) {
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

/// Luồng trực chính.
List<String> mainDutyFlowLabels(String? positionTitle) {
  if (isNursingBlockTitle(positionTitle)) {
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

/// Nhãn luồng duyệt theo loại đơn + chức danh (hub / intro banner).
List<String> flowLabelsForRequestType(
  String typeKey,
  Iterable<String> configStageLabels,
  String? positionTitle,
) {
  return switch (typeKey) {
    'probation-conversion' => probationFlowLabels(positionTitle),
    'main-duty-authorization' => mainDutyFlowLabels(positionTitle),
    _ => filterDisplayStages(
        configStageLabels,
        positionTitle: positionTitle,
      ),
  };
}
