/** Khóa JSON từ backend (WorkforceProfileMapper) → nhãn tiếng Việt */
export const WORKFORCE_FIELD_LABELS: Record<string, string> = {
  payrollDisplayName: 'Tên hiển thị (bảng lương)',
  specialty: 'Chuyên ngành / chuyên môn',
  degree: 'Trình độ / bằng cấp',
  professionalDiploma: 'Văn bằng chuyên môn',
  practiceScope: 'Phạm vi hành nghề',
  practiceCertNumber: 'Số chứng chỉ hành nghề (CCHN)',
  practiceCertDateRaw: 'Ngày cấp CCHN',
  otherTrainingCertificates: 'Chứng chỉ đào tạo khác',
  cki: 'CKI',
  bankAccount: 'STK nhận lương',
  bankName: 'Ngân hàng nhận lương',
  attendanceCode: 'Mã chấm công',
  insuranceParticipation: 'Tham gia BHXH',
  socialInsuranceBook: 'Số sổ BHXH',
  idCardIssueDate: 'Ngày cấp CCCD/CMND',
  probationStartDate: 'Ngày bắt đầu thử việc',
  officialStartDate: 'Ngày làm chính thức',
  contractNumber: 'Số hợp đồng lao động',
  contractSignDate: 'Ngày ký hợp đồng',
  contractTerm: 'Thời hạn hợp đồng',
  workUnitDetail: 'Bộ phận / đơn vị chi tiết',
  workforceNotes: 'Ghi chú',
  dependentsInfo: 'Người phụ thuộc',
  ethnicity: 'Dân tộc',
  placeOfOrigin: 'Nguyên quán',
  maritalStatus: 'Tình trạng hôn nhân',
  bloodType: 'Nhóm máu',
  emergencyContact: 'Người liên hệ khẩn cấp',
  emergencyPhone: 'Điện thoại liên hệ khẩn cấp',
};

export function workforceFieldLabel(key: string): string {
  return WORKFORCE_FIELD_LABELS[key] ?? key.replace(/([A-Z])/g, ' $1').replace(/^./, (s) => s.toUpperCase()).trim();
}

/** Nhóm hiển thị trên UI (chỉ các khóa có trong map) */
export const WORKFORCE_SECTIONS: { title: string; keys: string[] }[] = [
  {
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
  },
  {
    title: 'Lương & ngân hàng',
    keys: ['payrollDisplayName', 'bankAccount', 'bankName', 'attendanceCode'],
  },
  {
    title: 'Bảo hiểm',
    keys: ['insuranceParticipation', 'socialInsuranceBook'],
  },
  {
    title: 'Ngày thử việc & chính thức',
    keys: ['idCardIssueDate', 'probationStartDate', 'officialStartDate'],
  },
  {
    title: 'Hợp đồng (Excel)',
    keys: ['contractNumber', 'contractSignDate', 'contractTerm'],
  },
  {
    title: 'Thông tin bổ sung',
    keys: [
      'ethnicity',
      'placeOfOrigin',
      'maritalStatus',
      'bloodType',
      'emergencyContact',
      'emergencyPhone',
      'workUnitDetail',
      'dependentsInfo',
      'workforceNotes',
    ],
  },
];
