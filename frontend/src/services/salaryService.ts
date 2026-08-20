import api from './api';

export type ComputedSalaryGrade = {
  gradeLevel: number;
  gradeLabel: string;
  yearsRange: string;
  coefficient: number;
  insuranceSalary: number;
  productSalary: number;
  scaleSalary: number;
};

export type EarlyRaiseConversion = {
  raiseDate?: string | null;
  years: number;
};

export type EmployeeSalaryProfile = {
  employeeId: number;
  salaryCategory: 'DOCTOR' | 'EMPLOYEE' | null;
  employeeBlock: 'DIRECT' | 'INDIRECT' | null;
  qualification: string | null;
  tierGroup: number;
  doctorQualificationCode: string | null;
  qualificationNote: string | null;
  yearsOfService: number;
  seniorityYears: number;
  degreeConversionYears: number;
  priorRaiseYears: number;
  earlyRaiseConversions?: EarlyRaiseConversion[];
  professionalAttractionSalary: number;
  salaryScaleStartDate?: string | null;
  seniorityAsOfDate?: string | null;
  baseSeniorityYears?: number | null;
  ldg?: boolean;
  importedInsuranceSalary?: number | null;
  importedProductSalary?: number | null;
  computedGrade: ComputedSalaryGrade;
  totalSalary: number;
  canViewSensitive: boolean;
  canEdit: boolean;
};

export type EmployeeSalaryProfileRequest = {
  salaryCategory: 'DOCTOR' | 'EMPLOYEE';
  employeeBlock?: 'DIRECT' | 'INDIRECT' | null;
  qualification?: string | null;
  tierGroup?: number;
  doctorQualificationCode?: string | null;
  qualificationNote?: string | null;
  degreeConversionYears?: number;
  priorRaiseYears?: number;
  earlyRaiseConversions?: EarlyRaiseConversion[];
  professionalAttractionSalary?: number;
  salaryScaleStartDate?: string | null;
  seniorityAsOfDate?: string | null;
  baseSeniorityYears?: number | null;
  ldg?: boolean | null;
  fixedGradeLabel?: string | null;
  importedInsuranceSalary?: number | null;
  importedProductSalary?: number | null;
};

export const EMPLOYEE_QUALIFICATIONS = [
  'Đại học',
  'Cao đẳng, trung cấp',
  'Lao động phổ thông',
] as const;

export type EmployeeScaleGrade = {
  gradeLevel: number;
  gradeLabel: string;
  yearsRange: string;
  coefficient: number;
  insuranceSalary: number;
  productSalary: number;
  totalIncome: number;
};

export type EmployeeScaleTier = {
  tierGroup: number;
  tierLabel: string;
  grades: EmployeeScaleGrade[];
};

export type EmployeeScale = {
  scaleType: string;
  title: string;
  baseTotalAtCoef1: number;
  baseInsuranceAtCoef1: number;
  baseProductAtCoef1: number;
  tiers: EmployeeScaleTier[];
};

export type DoctorScaleEntry = {
  id: number;
  qualificationCode: string;
  qualificationName: string;
  timeLabel: string;
  yearsMin: number;
  yearsMax: number | null;
  totalSalary: number;
};

export type SalaryScaleEntry = {
  id?: number;
  scaleType: string;
  qualification: string;
  gradeLevel: number;
  coefficient: number;
  baseInsuranceSalary: number;
  productSalary: number;
  totalIncome: number;
};

export type AllSalaryScales = {
  employeeDirect: EmployeeScale;
  employeeIndirect: EmployeeScale;
  doctor: DoctorScaleEntry[];
  entriesDirect?: SalaryScaleEntry[];
  entriesIndirect?: SalaryScaleEntry[];
  /** ALL = ADMIN đã mở khóa; DIRECT | INDIRECT | DOCTOR = đúng đối tượng của người xem; NONE = chưa cấu hình */
  viewerScope?: 'ALL' | 'DIRECT' | 'INDIRECT' | 'DOCTOR' | 'NONE';
};

export type SalaryExportRow = {
  employeeCode: string;
  fullName: string;
  department: string;
  yearsOfService: number;
  seniorityYears: number;
  grade: string;
  insuranceSalary: number;
  productSalary: number;
  attractionSalary: number;
  totalSalary: number;
};

export type SalaryGradeReviewRow = {
  employeeId: number;
  employeeCode: string;
  fullName: string;
  department: string;
  position: string;
  salaryCategory: 'DOCTOR' | 'EMPLOYEE';
  employeeBlock: 'DIRECT' | 'INDIRECT' | '';
  qualification: string;
  effectiveDate: string;
  lastRaiseDate?: string | null;
  reviewSource: 'MANUAL_REVIEW_DATE' | 'SENIORITY_SCALE';
  seniorityYears: number;
  currentGradeLevel: number;
  currentGrade: string;
  nextGradeLevel: number;
  nextGrade: string;
  currentSalary: number;
  nextSalary: number;
  increaseAmount: number;
  increasePercent: number;
  daysUntil: number;
  timingStatus: 'UPCOMING' | 'TODAY' | 'PASSED';
};

export type SalaryGradeReviewReport = {
  year: number;
  month: number;
  generatedAt: string;
  total: number;
  upcoming: number;
  today: number;
  passed: number;
  increaseTotal: number;
  rows: SalaryGradeReviewRow[];
};

export async function fetchSalaryGradeReviews(year: number, month: number) {
  const { data } = await api.get<SalaryGradeReviewReport>('/v1/salary-profiles/grade-reviews', {
    ...salaryAccessConfig(),
    params: { year, month },
  });
  return data;
}

export async function downloadSalaryGradeReviewExcel(year: number, month: number) {
  const { data } = await api.get<Blob>('/v1/salary-profiles/grade-reviews/excel', {
    ...salaryAccessConfig(),
    params: { year, month },
    responseType: 'blob',
  });
  const url = URL.createObjectURL(data);
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = `danh-sach-nang-bac-luong-${year}-${String(month).padStart(2, '0')}.xlsx`;
  document.body.appendChild(anchor);
  anchor.click();
  anchor.remove();
  URL.revokeObjectURL(url);
}

export async function fetchSalaryScales(mine = false): Promise<AllSalaryScales> {
  const config = salaryAccessConfig();
  const { data } = await api.get<AllSalaryScales>('/v1/salary-scales', {
    ...config,
    params: mine ? { mine: true } : undefined,
  });
  return data;
}

export async function updateScaleBase(
  scaleType: 'EMPLOYEE_DIRECT' | 'EMPLOYEE_INDIRECT',
  baseTotalIncome: number,
  qualification: string,
): Promise<EmployeeScale> {
  const { data } = await api.put<EmployeeScale>(`/v1/salary-scales/employee/${scaleType}/base`, {
    baseTotalIncome,
    qualification,
  }, salaryAccessConfig());
  return data;
}

export async function fetchSalaryProfile(employeeId: number): Promise<EmployeeSalaryProfile> {
  const { data } = await api.get<EmployeeSalaryProfile>(
    `/v1/salary-profiles/employees/${employeeId}`,
    salaryAccessConfig(),
  );
  return data;
}

export async function upsertSalaryProfile(
  employeeId: number,
  body: EmployeeSalaryProfileRequest,
): Promise<EmployeeSalaryProfile> {
  const { data } = await api.put<EmployeeSalaryProfile>(
    `/v1/salary-profiles/employees/${employeeId}`,
    body,
    salaryAccessConfig(),
  );
  return data;
}

export async function recalculateAllSalaries(): Promise<{ recalculated: number }> {
  const { data } = await api.post<{ recalculated: number }>(
    '/v1/salary-profiles/recalculate-all',
    undefined,
    salaryAccessConfig(),
  );
  return data;
}

export async function exportSalaryProfiles(): Promise<SalaryExportRow[]> {
  const { data } = await api.get<SalaryExportRow[]>('/v1/salary-profiles/export', salaryAccessConfig());
  return data;
}

const SALARY_TOKEN_KEY = 'minhan_salary_access';
const SALARY_EXPIRY_KEY = 'minhan_salary_access_expiry';

function salaryAccessConfig() {
  const token = getSalaryAccessToken();
  return token ? { headers: { 'X-Salary-Access-Token': token } } : {};
}

export function getSalaryAccessToken(): string | null {
  const token = sessionStorage.getItem(SALARY_TOKEN_KEY);
  const expiresAt = sessionStorage.getItem(SALARY_EXPIRY_KEY);
  if (!token || !expiresAt || Date.parse(expiresAt) <= Date.now()) {
    clearSalaryAccess();
    return null;
  }
  return token;
}

export function clearSalaryAccess() {
  sessionStorage.removeItem(SALARY_TOKEN_KEY);
  sessionStorage.removeItem(SALARY_EXPIRY_KEY);
}

export async function unlockSalaryAccess(password: string): Promise<void> {
  const { data } = await api.post<{ token: string; expiresAt: string }>('/v1/salary-profiles/unlock', {
    password,
  });
  sessionStorage.setItem(SALARY_TOKEN_KEY, data.token);
  sessionStorage.setItem(SALARY_EXPIRY_KEY, data.expiresAt);
}

export const DOCTOR_QUALIFICATIONS = [
  { code: 'DK', label: 'Bác sỹ chưa có CCHN (ĐK)' },
  { code: 'DKCT', label: 'Bác sỹ chưa có CCHN (ĐKCT)' },
  { code: 'CCHN', label: 'Bác sỹ có CCHN' },
  { code: 'CCHNCT', label: 'Bác sỹ có CCHN (có thời hạn)' },
  { code: 'CK1', label: 'CK1' },
  { code: 'CK2', label: 'CK2' },
  { code: 'NOI_TRU', label: 'Nội trú' },
] as const;

export function formatMoney(n: number | null | undefined): string {
  if (n == null || Number.isNaN(n)) return '—';
  return `${Number(n).toLocaleString('vi-VN')} đ`;
}

export function formatYears(n: number | null | undefined): string {
  if (n == null || Number.isNaN(n)) return '—';
  return Number(n).toFixed(2).replace(/\.?0+$/, '');
}

/** Mốc thâm niên mặc định theo file nhân lực. */
export const DEFAULT_SENIORITY_AS_OF = '2026-06-30';

/** Số năm = số ngày / 365 (giống backend). */
export function yearsBetweenDays(
  startDate?: string | null,
  endDate: Date | string = new Date(),
): number {
  if (!startDate) return 0;
  const start = new Date(`${String(startDate).slice(0, 10)}T00:00:00`);
  const end =
    typeof endDate === 'string'
      ? new Date(`${String(endDate).slice(0, 10)}T00:00:00`)
      : new Date(endDate.getFullYear(), endDate.getMonth(), endDate.getDate());
  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) return 0;
  const days = Math.max(0, Math.floor((end.getTime() - start.getTime()) / 86_400_000));
  return days / 365;
}

/**
 * Có mốc 30/06 khi đã nhập số thâm niên mốc.
 * Riêng 0 + có ngày bắt đầu thang → không dùng mốc (thường nhập 0 thay vì để trống).
 */
export function hasSeniorityMilestone(
  baseSeniorityYears?: number | string | null,
  salaryScaleStartDate?: string | null,
): boolean {
  if (baseSeniorityYears === '' || baseSeniorityYears == null || Number.isNaN(Number(baseSeniorityYears))) {
    return false;
  }
  const base = Number(baseSeniorityYears);
  if (base === 0 && salaryScaleStartDate) {
    return false;
  }
  return true;
}

/**
 * Thâm niên hiện tại:
 * - Có mốc: base + (hôm nay − asOf) / 365
 * - Không mốc: (hôm nay − ngày bắt đầu thang) / 365
 * + quy đổi nâng sớm / chuyển đổi bằng cấp.
 */
export function resolveLiveSeniorityYears(opts: {
  baseSeniorityYears?: number | string | null;
  seniorityAsOfDate?: string | null;
  salaryScaleStartDate?: string | null;
  priorRaiseYears?: number | string | null;
  degreeConversionYears?: number | string | null;
  ldg?: boolean;
}): number {
  if (opts.ldg) return 0;
  const prior = Math.max(0, Number(opts.priorRaiseYears) || 0);
  const degree = Math.max(0, Number(opts.degreeConversionYears) || 0);
  const baseRaw = opts.baseSeniorityYears;
  const base =
    baseRaw === '' || baseRaw == null || Number.isNaN(Number(baseRaw))
      ? null
      : Number(baseRaw);
  let years: number;
  if (hasSeniorityMilestone(base, opts.salaryScaleStartDate)) {
    const asOf = opts.seniorityAsOfDate?.slice(0, 10) || DEFAULT_SENIORITY_AS_OF;
    years = (base ?? 0) + yearsBetweenDays(asOf);
  } else {
    years = yearsBetweenDays(opts.salaryScaleStartDate);
  }
  return years + prior + degree;
}

export function formatLiveSeniorityPreview(opts: Parameters<typeof resolveLiveSeniorityYears>[0]): string {
  if (opts.ldg) return 'LĐG';
  const hasBase = hasSeniorityMilestone(opts.baseSeniorityYears, opts.salaryScaleStartDate);
  if (!hasBase && !opts.salaryScaleStartDate) {
    return 'Nhập mốc 30/06 hoặc ngày bắt đầu thang';
  }
  return `${resolveLiveSeniorityYears(opts).toFixed(2)} năm`;
}

export function downloadSalaryExport(rows: SalaryExportRow[]) {
  const header = [
    'Mã NV',
    'Họ tên',
    'Phòng ban',
    'Năm công tác',
    'Thâm niên',
    'Bậc',
    'Lương BH',
    'Lương SP',
    'Thu hút',
    'Tổng lương',
  ];
  const lines = [
    header.join('\t'),
    ...rows.map((r) =>
      [
        r.employeeCode,
        r.fullName,
        r.department,
        r.yearsOfService,
        r.seniorityYears,
        r.grade,
        r.insuranceSalary,
        r.productSalary,
        r.attractionSalary,
        r.totalSalary,
      ].join('\t'),
    ),
  ];
  const blob = new Blob(['\uFEFF' + lines.join('\n')], { type: 'text/tab-separated-values;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `bang-luong-${new Date().toISOString().slice(0, 10)}.tsv`;
  a.click();
  URL.revokeObjectURL(url);
}
