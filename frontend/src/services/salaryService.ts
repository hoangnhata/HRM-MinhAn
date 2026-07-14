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
  professionalAttractionSalary: number;
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
  professionalAttractionSalary?: number;
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

export async function fetchSalaryScales(): Promise<AllSalaryScales> {
  const { data } = await api.get<AllSalaryScales>('/v1/salary-scales');
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
  });
  return data;
}

export async function fetchSalaryProfile(employeeId: number): Promise<EmployeeSalaryProfile> {
  const { data } = await api.get<EmployeeSalaryProfile>(`/v1/salary-profiles/employees/${employeeId}`);
  return data;
}

export async function upsertSalaryProfile(
  employeeId: number,
  body: EmployeeSalaryProfileRequest,
): Promise<EmployeeSalaryProfile> {
  const { data } = await api.put<EmployeeSalaryProfile>(`/v1/salary-profiles/employees/${employeeId}`, body);
  return data;
}

export async function recalculateAllSalaries(): Promise<{ recalculated: number }> {
  const { data } = await api.post<{ recalculated: number }>('/v1/salary-profiles/recalculate-all');
  return data;
}

export async function exportSalaryProfiles(): Promise<SalaryExportRow[]> {
  const { data } = await api.get<SalaryExportRow[]>('/v1/salary-profiles/export');
  return data;
}

export const DOCTOR_QUALIFICATIONS = [
  { code: 'DK', label: 'Bác sỹ chưa có CCHN' },
  { code: 'CCHN', label: 'Bác sỹ có CCHN' },
  { code: 'CCHNCT', label: 'Bác sỹ có CCHN (có thời hạn)' },
  { code: 'CK1', label: 'CK1' },
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
