import api from './api';
import { fetchDepartments as fetchDepartmentRows } from './departmentService';

export type Page<T> = {
  content: T[];
  totalElements: number;
  totalPages: number;
  number: number;
  size: number;
};

export type EmployeeSummary = {
  id: number;
  employeeCode?: string | null;
  userId: number;
  username: string;
  fullName: string;
  departmentName: string;
  workUnitDetail?: string | null;
  positionTitle: string;
  role: string;
  status: string;
  hireDate: string;
  probationStartDate?: string | null;
  probationMonths?: number | null;
  probationOverdue?: boolean | null;
  insuranceParticipation?: string | null;
  maternityLeave?: boolean | null;
  onTraining?: boolean | null;
  mainDutyAuthorized?: boolean | null;
  /** FULL_TIME | PART_TIME */
  employmentType?: string | null;
};

export type EmployeeStatusGroup = 'WORKING' | 'TRIAL' | 'OFFICIAL' | 'TERMINATED';

export type OfficialWorkFilter = 'WORKING' | 'MATERNITY_LEAVE' | 'FULL_TIME' | 'PART_TIME';

export const EMPLOYMENT_STATUS_LABEL: Record<string, string> = {
  ACTIVE: 'Chính thức',
  PROBATION: 'Thử việc',
  INTERN: 'Thực tập',
  ON_LEAVE: 'Nghỉ phép',
  TERMINATED: 'Nghỉ việc',
};

export const EMPLOYMENT_TYPE_LABEL: Record<string, string> = {
  FULL_TIME: 'Toàn thời gian',
  PART_TIME: 'Bán thời gian',
};

export type EmployeeDetail = {
  id: number;
  employeeCode?: string | null;
  userId: number;
  username: string;
  email: string;
  role: string;
  fullName: string;
  phone?: string;
  gender?: string | null;
  idCardNumber?: string | null;
  dateOfBirth?: string | null;
  address?: string | null;
  departmentId: number;
  departmentName: string;
  positionId: number;
  positionTitle: string;
  hireDate: string;
  status: string;
  /** true = trực chính; false = chỉ trực kèm (TK). */
  mainDutyAuthorized?: boolean;
  /** FULL_TIME | PART_TIME */
  employmentType?: string | null;
  salary?: {
    baseSalary: number;
    allowance: number;
    lastRaiseDate?: string;
    nextReviewDate?: string;
  };
  contracts: Array<{
    id: number;
    contractType: string;
    startDate: string;
    endDate?: string;
    salaryBase?: number;
  }>;
  workforceProfile?: Record<string, unknown> | null;
};

export type DepartmentOption = { id: number; code: string; name: string };
export type PositionOption = { id: number; code: string; title: string; levelRank: number };

export type CreatableUserRole = 'EMPLOYEE' | 'HR' | 'HR2' | 'HEAD_DEPARTMENT' | 'HEAD_HR' | 'HEAD_NURSING';

/** Vai trò tài khoản (bao gồm ADMIN — chỉ chỉnh khi sửa nhân viên). */
export type EmployeeAccountRole =
  | 'ADMIN'
  | 'EMPLOYEE'
  | 'HR'
  | 'HR2'
  | 'HEAD_DEPARTMENT'
  | 'HEAD_HR'
  | 'HEAD_NURSING'
  | 'DIRECTOR';

export type WorkforceDetailsPayload = {
  payrollDisplayName?: string;
  specialty?: string;
  degree?: string;
  professionalDiploma?: string;
  practiceScope?: string;
  practiceCertNumber?: string;
  practiceCertDateRaw?: string;
  otherTrainingCertificates?: string;
  cki?: string;
  bankAccount?: string;
  bankName?: string;
  attendanceCode?: string;
  insuranceParticipation?: string;
  socialInsuranceBook?: string;
  idCardIssueDate?: string;
  probationStartDate?: string;
  officialStartDate?: string;
  contractNumber?: string;
  contractSignDate?: string;
  contractTerm?: string;
  workUnitDetail?: string;
  workforceNotes?: string;
  dependentsInfo?: string;
  ethnicity?: string;
  placeOfOrigin?: string;
  maritalStatus?: string;
  bloodType?: string;
  emergencyContact?: string;
  emergencyPhone?: string;
};

export type EmployeeCreatePayload = {
  username?: string;
  password?: string;
  email?: string;
  role: CreatableUserRole;
  fullName: string;
  phone?: string;
  idCardNumber?: string;
  dateOfBirth?: string;
  address?: string;
  gender?: string;
  departmentId: number;
  positionId?: number;
  hireDate?: string;
  baseSalary?: number;
  /** FULL_TIME (TTG) | PART_TIME (BTG) */
  employmentType?: 'FULL_TIME' | 'PART_TIME';
  /** Theo tab: ACTIVE / PROBATION / INTERN / … */
  status?: 'ACTIVE' | 'PROBATION' | 'INTERN' | 'ON_LEAVE' | 'TERMINATED';
  workforce?: WorkforceDetailsPayload;
};

export type EmployeeUpdatePayload = {
  email?: string;
  role?: EmployeeAccountRole;
  fullName?: string;
  phone?: string;
  idCardNumber?: string;
  dateOfBirth?: string;
  address?: string;
  gender?: string;
  departmentId?: number;
  positionId?: number;
  hireDate?: string;
  /** Lương & phụ cấp (cập nhật khi có gửi) */
  baseSalary?: number;
  allowance?: number;
  lastRaiseDate?: string;
  nextReviewDate?: string;
  status: 'ACTIVE' | 'PROBATION' | 'INTERN' | 'ON_LEAVE' | 'TERMINATED';
  /** true = trực chính; false = chỉ trực kèm (TK). */
  mainDutyAuthorized?: boolean;
  employmentType?: 'FULL_TIME' | 'PART_TIME';
  workforce?: WorkforceDetailsPayload;
};

export type EmployeeListParams = {
  page?: number;
  size?: number;
  q?: string;
  departmentId?: number;
  /** Bộ phận (workUnitDetail) */
  workUnit?: string;
  status?: string;
  statusGroup?: EmployeeStatusGroup;
  officialWorkFilter?: OfficialWorkFilter;
};

/** NV để chọn trên phiếu đánh giá theo tháng — toàn bộ NV ACTIVE (mọi vai trò được gọi API). */
export async function fetchEvaluationRoster() {
  const { data } = await api.get<EmployeeSummary[]>('/v1/employees/evaluation-roster');
  return data;
}

export async function fetchEmployees(params: EmployeeListParams = {}) {
  const { page = 0, size = 10, q, departmentId, workUnit, status, statusGroup, officialWorkFilter } = params;
  const { data } = await api.get<Page<EmployeeSummary>>('/v1/employees', {
    params: {
      page,
      size,
      sort: 'id,desc',
      ...(q?.trim() ? { q: q.trim() } : {}),
      ...(departmentId != null ? { departmentId } : {}),
      ...(workUnit?.trim() ? { workUnit: workUnit.trim() } : {}),
      ...(status ? { status } : {}),
      ...(statusGroup ? { statusGroup } : {}),
      ...(officialWorkFilter ? { officialWorkFilter } : {}),
    },
  });
  return data;
}

export async function fetchEmployee(id: number) {
  const { data } = await api.get<EmployeeDetail>(`/v1/employees/${id}`);
  return data;
}

export async function fetchMe() {
  const { data } = await api.get<EmployeeDetail>('/v1/employees/me');
  return data;
}

export type DashboardStats = {
  totalEmployees: number;
  activeEmployees: number;
  maternityLeave: number;
  departments: number;
  employeeRoleAccounts: number;
  accountsMatchEmployees: boolean;
  totalPdfDocuments: number;
  salaryReviewsDueSoon: number;
  /** Biểu đồ: trạng thái */
  statusBreakdown?: { working: number; maternityLeave: number; trial: number; terminated: number };
  /** Biểu đồ: theo phòng ban */
  employeesByDepartment?: Array<{
    departmentId: number;
    departmentName: string;
    count: number;
    officialCount: number;
    trialCount: number;
  }>;
  /** Biểu đồ: nhận việc 12 tháng */
  hiresByMonth?: Array<{
    label: string;
    count: number;
    year: number;
    month: number;
    officialCount: number;
    trialCount: number;
  }>;
};

export async function fetchDashboardHiresInMonth(year: number, month: number) {
  const { data } = await api.get<EmployeeSummary[]>(`/v1/dashboard/hires/${year}/${month}/employees`);
  return data;
}

export async function fetchDashboardDepartmentEmployees(departmentId: number) {
  const { data } = await api.get<EmployeeSummary[]>(`/v1/dashboard/departments/${departmentId}/employees`);
  return data;
}

export async function fetchDashboardStats() {
  const { data } = await api.get<DashboardStats>('/v1/dashboard/stats');
  return data;
}

export type NursingDashboardStats = {
  totalInBlock: number;
  officialCount: number;
  trialCount: number;
  mainDutyAuthorized: number;
  departmentsCovered: number;
  pendingDeployments: number;
  pendingProbation: number;
  pendingMainDuty: number;
  pendingTotal: number;
  bySubGroup: Array<{ label: string; count: number }>;
  byDepartment: Array<{
    departmentId?: number | null;
    departmentName: string;
    count: number;
    officialCount: number;
    trialCount: number;
  }>;
  statusBreakdown: {
    official: number;
    trial: number;
    mainDutyAuthorized: number;
  };
};

export async function fetchNursingDashboardStats() {
  const { data } = await api.get<NursingDashboardStats>('/v1/dashboard/nursing-stats');
  return data;
}

export async function fetchNursingDepartmentEmployees(departmentId: number) {
  const { data } = await api.get<EmployeeSummary[]>(
    `/v1/dashboard/nursing/departments/${departmentId}/employees`,
  );
  return data;
}

export async function fetchDepartments() {
  const rows = await fetchDepartmentRows();
  return rows.map(({ id, code, name }) => ({ id, code, name }));
}

export async function fetchPositions() {
  const { data } = await api.get<PositionOption[]>('/v1/positions');
  return data;
}

export async function createEmployee(payload: EmployeeCreatePayload) {
  const { data } = await api.post<EmployeeDetail>('/v1/employees', payload);
  return data;
}

export async function updateEmployee(id: number, payload: EmployeeUpdatePayload) {
  const { data } = await api.put<EmployeeDetail>(`/v1/employees/${id}`, payload);
  return data;
}

export async function deleteEmployee(id: number) {
  await api.delete(`/v1/employees/${id}`);
}

export async function permanentlyDeleteEmployee(id: number) {
  await api.delete(`/v1/employees/${id}/permanent`);
}

export async function confirmOfficial(id: number, officialDate?: string) {
  const { data } = await api.post<EmployeeDetail>(`/v1/employees/${id}/confirm-official`, {
    officialDate: officialDate ?? null,
  });
  return data;
}
