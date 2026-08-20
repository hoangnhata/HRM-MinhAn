/// Nhãn / nhóm trường hồ sơ nhân lực — đồng bộ web `workforceFieldLabels.ts`.
const workforceFieldLabels = <String, String>{
  'payrollDisplayName': 'Tên hiển thị (bảng lương)',
  'specialty': 'Chuyên ngành / chuyên môn',
  'degree': 'Trình độ / bằng cấp',
  'professionalDiploma': 'Văn bằng chuyên môn',
  'practiceScope': 'Phạm vi hành nghề',
  'practiceCertNumber': 'Số chứng chỉ hành nghề (CCHN)',
  'practiceCertDateRaw': 'Ngày cấp CCHN',
  'otherTrainingCertificates': 'Chứng chỉ đào tạo khác',
  'cki': 'CKI',
  'bankAccount': 'STK nhận lương',
  'bankName': 'Ngân hàng nhận lương',
  'attendanceCode': 'Mã chấm công',
  'insuranceParticipation': 'Tham gia BHXH',
  'socialInsuranceBook': 'Số sổ BHXH',
  'idCardIssueDate': 'Ngày cấp CCCD/CMND',
  'probationStartDate': 'Ngày bắt đầu thử việc',
  'officialStartDate': 'Ngày làm chính thức',
  'contractNumber': 'Số hợp đồng lao động',
  'contractSignDate': 'Ngày ký hợp đồng',
  'contractTerm': 'Thời hạn hợp đồng',
  'trialType': 'Loại thử việc / thực hành',
  'workUnitDetail': 'Bộ phận',
  'workforceNotes': 'Ghi chú',
  'dependentsInfo': 'Người phụ thuộc',
  'ethnicity': 'Dân tộc',
  'placeOfOrigin': 'Nguyên quán',
  'maritalStatus': 'Tình trạng hôn nhân',
  'bloodType': 'Nhóm máu',
  'emergencyContact': 'Người liên hệ khẩn cấp',
  'emergencyPhone': 'Điện thoại liên hệ khẩn cấp',
};

const workforceSections = <({String title, List<String> keys})>[
  (
    title: 'Chuyên môn & chứng chỉ',
    keys: [
      'specialty',
      'degree',
      'professionalDiploma',
      'practiceScope',
      'practiceCertNumber',
      'practiceCertDateRaw',
      'otherTrainingCertificates',
      'cki',
    ],
  ),
  (
    title: 'Lương & ngân hàng',
    keys: ['payrollDisplayName', 'bankAccount', 'bankName', 'attendanceCode'],
  ),
  (
    title: 'Bảo hiểm',
    keys: ['insuranceParticipation', 'socialInsuranceBook'],
  ),
  (
    title: 'Ngày thử việc & chính thức',
    keys: ['idCardIssueDate', 'probationStartDate', 'officialStartDate'],
  ),
  (
    title: 'Hợp đồng (Excel)',
    keys: ['contractNumber', 'contractSignDate', 'contractTerm'],
  ),
  (
    title: 'Thông tin bổ sung',
    keys: [
      'ethnicity',
      'placeOfOrigin',
      'maritalStatus',
      'bloodType',
      'emergencyContact',
      'emergencyPhone',
      'workUnitDetail',
      'trialType',
      'dependentsInfo',
      'workforceNotes',
    ],
  ),
];

String workforceFieldLabel(String key) {
  final known = workforceFieldLabels[key];
  if (known != null) return known;
  return key
      .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[1]}')
      .trim();
}

bool hasWorkforceValue(Object? value) {
  if (value == null) return false;
  final text = value.toString().trim();
  return text.isNotEmpty && text != 'null' && text != '—';
}
