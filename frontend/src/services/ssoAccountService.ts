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
  /** Vai trò ERP — UserAccounts.RoleId */
  roleId?: number | null;
  /** Vai trò Tài sản — UserAccounts.roleId_ts */
  roleIdTs?: number | null;
  fullName?: string | null;
  departmentName?: string | null;
  workUnitDetail?: string | null;
  hrmEmployeeId?: number | null;
};

export async function fetchSsoHrmRoles() {
  const { data } = await api.get<SsoRoleCatalog[]>('/v1/sso/hrm-roles');
  return data;
}

export async function fetchSsoAccounts(params?: {
  q?: string;
  departmentId?: number;
  workUnit?: string;
}) {
  const { data } = await api.get<SsoAccountRow[]>('/v1/sso/accounts', {
    params: {
      ...(params?.q?.trim() ? { q: params.q.trim() } : {}),
      ...(params?.departmentId != null ? { departmentId: params.departmentId } : {}),
      ...(params?.workUnit?.trim() ? { workUnit: params.workUnit.trim() } : {}),
    },
  });
  return data;
}

export async function assignSsoHrmRole(accountId: number, roleCode: string) {
  const { data } = await api.put<SsoAccountRow>(`/v1/sso/accounts/${accountId}/hrm-role`, { roleCode });
  return data;
}

export async function assignSsoErpRole(accountId: number, roleId: number) {
  const { data } = await api.put(`/v1/sso/accounts/${accountId}/erp-role`, { roleId });
  return data;
}

export async function assignSsoAssetRole(accountId: number, roleIdTs: number) {
  const { data } = await api.put(`/v1/sso/accounts/${accountId}/asset-role`, { roleIdTs });
  return data;
}

/** Nhân viên HRM chưa có tài khoản đăng nhập (UserEnrollNumber = mã chấm công). */
export type EmployeeAccountCandidate = {
  id: number;
  name: string;
  dept?: string | null;
  phone?: string | null;
  cccd?: string | null;
  missingPhone?: boolean | null;
  employeeStatus?: string | null;
  hrmEmployeeId?: number | null;
  employeeCode?: string | null;
  attendanceCode?: string | null;
  missingAttendanceCode?: boolean | null;
  employmentType?: string | null;
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
  /** TRIAL | OFFICIAL_TTG | OFFICIAL_BTG | OFFICIAL */
  trialGroup?: string;
}) {
  const { data } = await api.get<EmployeeAccountCandidatePage>('/hrm/employees', {
    params: {
      hasAccount: false,
      page: params?.page ?? 1,
      limit: params?.limit ?? 100,
      ...(params?.search?.trim() ? { search: params.search.trim() } : {}),
      ...(params?.dept?.trim() ? { dept: params.dept.trim() } : {}),
      ...(params?.trialGroup?.trim() ? { trialGroup: params.trialGroup.trim() } : {}),
    },
  });
  return data;
}

export type GrantAccountPayload = {
  password?: string;
  /** SĐT đăng nhập — lưu vào HRM nếu NV chưa có / khi nhập mới lúc cấp TK */
  phone?: string;
  /** Vai trò ERP (UserAccounts.RoleId) */
  roleId?: number;
  roleIdTs?: number;
  /** Chức danh HRM — 6 role phần mềm (UserAppRoles) */
  hrmRoleCode?: string;
  /** Mã chấm công — lưu HRM + UserEnrollNumber SSO */
  attendanceCode?: string;
};

export type GrantAccountResult = { message: string; id: string };

export async function grantEmployeeAccount(userEnrollNumber: number, payload: GrantAccountPayload) {
  const { data } = await api.post<GrantAccountResult>(`/hrm/employees/${userEnrollNumber}/account`, payload);
  return data;
}

export type SsoWorkforceSyncResult = {
  scanned: number;
  accountsCreated: number;
  accountsUpdated: number;
  accountsDeactivated: number;
  accountsOrphansRemoved?: number;
  profilesOrphansRemoved?: number;
  publicUpserted: number;
  privateUpserted: number;
  relationDeptMatched?: number;
  relationDeptCreated?: number;
  skippedNoPhone: number;
  skippedNoEnroll: number;
  skippedDuplicatePhone?: number;
  failed: number;
  message: string;
};

/** Đồng bộ nhân lực HRM → SSO (cập nhật TK, xóa TK/hồ sơ không còn trong HRM). */
export async function syncWorkforceToSso() {
  const { data } = await api.post<SsoWorkforceSyncResult>('/v1/sso/sync-workforce');
  return data;
}
