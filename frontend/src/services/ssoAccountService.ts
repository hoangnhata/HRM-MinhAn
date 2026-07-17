import api from './api';

export type SsoRoleCatalog = {
  roleId: number;
  appCode: string;
  roleCode: string;
  roleName: string;
  active: boolean;
};

export type SsoAccountRow = {
  accountId: number;
  loginPhone: string;
  userEnrollNumber?: number | null;
  roleCode?: string | null;
  roleName?: string | null;
  fullName?: string | null;
  departmentName?: string | null;
  hrmEmployeeId?: number | null;
};

export async function fetchSsoHrmRoles() {
  const { data } = await api.get<SsoRoleCatalog[]>('/v1/sso/hrm-roles');
  return data;
}

export async function fetchSsoAccounts(params?: { q?: string; departmentId?: number }) {
  const { data } = await api.get<SsoAccountRow[]>('/v1/sso/accounts', {
    params: {
      ...(params?.q?.trim() ? { q: params.q.trim() } : {}),
      ...(params?.departmentId != null ? { departmentId: params.departmentId } : {}),
    },
  });
  return data;
}

export async function assignSsoHrmRole(accountId: number, roleCode: string) {
  const { data } = await api.put<SsoAccountRow>(`/v1/sso/accounts/${accountId}/hrm-role`, { roleCode });
  return data;
}

/** Nhân viên HRM chưa có tài khoản đăng nhập (UserEnrollNumber = mã chấm công). */
export type EmployeeAccountCandidate = {
  id: number;
  name: string;
  dept?: string | null;
  phone?: string | null;
  cccd?: string | null;
  roleId?: number | null;
  roleIdTs?: number | null;
};

export type EmployeeAccountCandidatePage = {
  total: number;
  page: number;
  limit: number;
  data: EmployeeAccountCandidate[];
};

export async function fetchEmployeesWithoutAccount(params?: {
  search?: string;
  page?: number;
  limit?: number;
  dept?: string;
}) {
  const { data } = await api.get<EmployeeAccountCandidatePage>('/hrm/employees', {
    params: {
      hasAccount: false,
      page: params?.page ?? 1,
      limit: params?.limit ?? 100,
      ...(params?.search?.trim() ? { search: params.search.trim() } : {}),
      ...(params?.dept?.trim() ? { dept: params.dept.trim() } : {}),
    },
  });
  return data;
}

export type GrantAccountPayload = {
  password?: string;
  /** Vai trò ERP (UserAccounts.RoleId) */
  roleId?: number;
  roleIdTs?: number;
  /** Chức danh HRM — 6 role phần mềm (UserAppRoles) */
  hrmRoleCode?: string;
};

export type GrantAccountResult = { message: string; id: string };

export async function grantEmployeeAccount(userEnrollNumber: number, payload: GrantAccountPayload) {
  const { data } = await api.post<GrantAccountResult>(`/hrm/employees/${userEnrollNumber}/account`, payload);
  return data;
}
