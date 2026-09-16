import api from './api';

export type ProfessionCode =
  'DOCTOR' | 'NURSE' | 'MIDWIFE' | 'TECHNICIAN' | 'ASSISTANT_PHYSICIAN' | 'PHARMACIST';

export type DegreeLevelCode =
  | 'TIEN_SI'
  | 'THAC_SI'
  | 'CK2'
  | 'CK1'
  | 'DAI_HOC'
  | 'CAO_DANG'
  | 'TRUNG_CAP'
  | 'SO_CAP'
  | 'OTHER'
  | 'MISSING';

export type DegreeLevelStat = {
  code: DegreeLevelCode;
  label: string;
  count: number;
  percent: number;
};

export type ProfessionKpi = {
  code: ProfessionCode;
  label: string;
  total: number;
  withDegree: number;
  missingDegree: number;
  missingPercent: number;
};

export type ProfessionBlock = ProfessionKpi & {
  byDegreeLevel: DegreeLevelStat[];
  rawDegreeBreakdown: { degree: string; count: number; percent: number }[];
  byDepartment: {
    departmentName: string;
    count: number;
    byDegreeLevel: DegreeLevelStat[];
  }[];
  byStatus: { status: string; label: string; count: number; percent: number }[];
};

export type QualificationDetail = {
  employeeId: number;
  employeeCode?: string | null;
  fullName: string;
  departmentId?: number | null;
  departmentName: string;
  positionTitle: string;
  status: string;
  statusLabel: string;
  professionCode: ProfessionCode;
  professionLabel: string;
  degreeRaw?: string | null;
  degreeLevelCode: DegreeLevelCode;
  degreeLevelLabel: string;
};

export type QualificationReport = {
  generatedAt: string;
  generatedAtLabel: string;
  totalHospitalStaff: number;
  totalInScope: number;
  missingDegreeCount: number;
  withDegreeCount: number;
  professionOrder: ProfessionCode[];
  degreeLevelOrder: DegreeLevelCode[];
  degreeLevelLabels: Record<string, string>;
  byProfession: ProfessionBlock[];
  degreeMatrix: {
    columns: { code: ProfessionCode; label: string }[];
    rows: {
      levelCode: DegreeLevelCode;
      levelLabel: string;
      counts: Record<string, number>;
      total: number;
    }[];
    columnTotals: Record<string, number>;
    grandTotal: number;
  };
  kpiCards: ProfessionKpi[];
  details: QualificationDetail[];
  practiceCertificate: PracticeCertificateReport;
};

export type CertStatusCode =
  'MISSING' | 'NO_DATE' | 'UNLIMITED' | 'VALID' | 'EXPIRING_SOON' | 'EXPIRED';

export type PracticeCertificateDetail = {
  employeeId: number;
  employeeCode?: string | null;
  fullName: string;
  departmentId?: number | null;
  departmentName: string;
  positionTitle: string;
  status: string;
  statusLabel: string;
  professionCode: ProfessionCode;
  professionLabel: string;
  certNumber?: string | null;
  certDateRaw?: string | null;
  issueDate?: string | null;
  issueDateLabel?: string | null;
  expiryDate?: string | null;
  expiryDateLabel?: string | null;
  daysToExpiry?: number | null;
  scope?: string | null;
  certStatusCode: CertStatusCode;
  certStatusLabel: string;
  needsAttention: boolean;
};

/**
 * Khối chứng chỉ hành nghề trong báo cáo trình độ chuyên môn.
 * Giấy phép cấp từ 01/01/2024 có hạn 5 năm; chứng chỉ cấp trước đó backend
 * ghi nhận là không thời hạn, không suy ngày hết hạn.
 */
export type PracticeCertificateReport = {
  kpi: {
    total: number;
    withCert: number;
    missing: number;
    coveragePercent: number;
    noDate: number;
    unlimited: number;
    valid: number;
    expiringSoon: number;
    expired: number;
    needsAttention: number;
  };
  statusOrder: CertStatusCode[];
  statusLabels: Record<CertStatusCode, string>;
  byStatus: {
    code: CertStatusCode;
    label: string;
    count: number;
    percent: number;
  }[];
  byProfession: {
    code: ProfessionCode;
    label: string;
    total: number;
    withCert: number;
    missing: number;
    coveragePercent: number;
    expiringSoon: number;
    expired: number;
    noDate: number;
  }[];
  byDepartment: {
    departmentName: string;
    total: number;
    withCert: number;
    missing: number;
    coveragePercent: number;
    needsAttention: number;
  }[];
  byIssueYear: { year: number; count: number }[];
  byScope: { scope: string; count: number; percent: number }[];
  details: PracticeCertificateDetail[];
};

export async function fetchProfessionalQualificationReport() {
  const { data } = await api.get<QualificationReport>('/v1/professional-qualification-reports');
  return data;
}

export async function downloadProfessionalQualificationExcel() {
  const { data } = await api.get<Blob>('/v1/professional-qualification-reports/excel', {
    responseType: 'blob',
  });
  const url = URL.createObjectURL(data);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'bao-cao-trinh-do-chuyen-mon.xlsx';
  a.click();
  URL.revokeObjectURL(url);
}
