import api from './api';

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
  positionTitle: string;
  role: string;
  status: string;
  hireDate: string;
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

export type CreatableUserRole = 'EMPLOYEE' | 'HR' | 'HEAD_DEPARTMENT' | 'HEAD_NURSING';

/** Vai trò tài khoản (bao gồm ADMIN — chỉ chỉnh khi sửa nhân viên). */
export type EmployeeAccountRole =
  | 'ADMIN'
  | 'EMPLOYEE'
  | 'HR'
  | 'HEAD_DEPARTMENT'
  | 'HEAD_NURSING';

export type EmployeeCreatePayload = {
  username: string;
  password: string;
  email: string;
  role: CreatableUserRole;
  fullName: string;
  phone?: string;
  idCardNumber?: string;
  dateOfBirth?: string;
  address?: string;
  gender?: string;
  departmentId: number;
  positionId: number;
  hireDate: string;
  baseSalary: number;
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
  status: 'ACTIVE' | 'ON_LEAVE' | 'TERMINATED';
};

export type EmployeeListParams = {
  page?: number;
  size?: number;
  q?: string;
  departmentId?: number;
  status?: string;
};

/** NV để chọn trên phiếu đánh giá theo tháng — toàn bộ NV ACTIVE (mọi vai trò được gọi API). */
export async function fetchEvaluationRoster() {
  const { data } = await api.get<EmployeeSummary[]>('/v1/employees/evaluation-roster');
  return data;
}

export async function fetchEmployees(params: EmployeeListParams = {}) {
  const { page = 0, size = 10, q, departmentId, status } = params;
  const { data } = await api.get<Page<EmployeeSummary>>('/v1/employees', {
    params: {
      page,
      size,
      sort: 'id,desc',
      ...(q?.trim() ? { q: q.trim() } : {}),
      ...(departmentId != null ? { departmentId } : {}),
      ...(status ? { status } : {}),
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
  onLeave: number;
  departments: number;
  employeeRoleAccounts: number;
  accountsMatchEmployees: boolean;
  totalPdfDocuments: number;
  salaryReviewsDueSoon: number;
  /** Biểu đồ: trạng thái */
  statusBreakdown?: { active: number; onLeave: number; terminated: number };
  /** Biểu đồ: theo phòng ban */
  employeesByDepartment?: Array<{ departmentName: string; count: number }>;
  /** Biểu đồ: nhận việc 12 tháng */
  hiresByMonth?: Array<{ label: string; count: number; year: number; month: number }>;
};

export async function fetchDashboardStats() {
  const { data } = await api.get<DashboardStats>('/v1/dashboard/stats');
  return data;
}

export async function fetchDepartments() {
  const { data } = await api.get<DepartmentOption[]>('/v1/departments');
  return data;
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
