import api from './api';

export type UserAccountAdminRow = {
  userId: number;
  username: string;
  email?: string | null;
  displayName?: string | null;
  role: string;
  enabled: boolean;
  directorApprovalEnabled: boolean;
  /** Được xem báo cáo nhân lực (cấp bởi Admin). */
  reportViewEnabled: boolean;
  /** Trưởng khoa chỉ quản lý bộ phận của mình. */
  workUnitScoped: boolean;
  mustChangePassword: boolean;
  hasSignature: boolean;
  employeeId?: number | null;
  employeeCode?: string | null;
  fullName?: string | null;
  phone?: string | null;
  attendanceCode?: string | null;
  departmentId?: number | null;
  departmentName?: string | null;
  workUnitDetail?: string | null;
  positionTitle?: string | null;
};

export type EmployeeWithoutAccount = {
  employeeId: number;
  employeeCode?: string | null;
  fullName: string;
  phone?: string | null;
  attendanceCode?: string | null;
  departmentId?: number | null;
  departmentName?: string | null;
  workUnitDetail?: string | null;
  positionTitle?: string | null;
  status?: string | null;
  missingPhone: boolean;
  missingAttendanceCode: boolean;
};

export type PageUserAccounts = {
  content: UserAccountAdminRow[];
  totalElements: number;
  totalPages: number;
  number: number;
  size: number;
};

export type PageWithoutAccount = {
  content: EmployeeWithoutAccount[];
  totalElements: number;
  totalPages: number;
  number: number;
  size: number;
};

export async function fetchUserAccounts(params: {
  q?: string;
  departmentId?: number;
  workUnitDetail?: string;
  role?: string;
  /** Chỉ tài khoản chưa đổi MK hoặc chưa có chữ ký. */
  inactiveOnly?: boolean;
  page?: number;
  size?: number;
}) {
  const { data } = await api.get<PageUserAccounts>('/v1/admin/user-accounts', { params });
  return data;
}

export async function fetchEmployeesWithoutAccount(params: {
  q?: string;
  departmentId?: number;
  workUnitDetail?: string;
  page?: number;
  size?: number;
}) {
  const { data } = await api.get<PageWithoutAccount>('/v1/admin/user-accounts/without-account', { params });
  return data;
}

export async function updateUserAccountRole(userId: number, role: string) {
  const { data } = await api.put<UserAccountAdminRow>(`/v1/admin/user-accounts/${userId}/role`, { role });
  return data;
}

export async function setUserAccountEnabled(userId: number, enabled: boolean) {
  const { data } = await api.put<UserAccountAdminRow>(`/v1/admin/user-accounts/${userId}/enabled`, { enabled });
  return data;
}

export async function updateUserAccountIdentifiers(
  userId: number,
  body: { phone?: string; attendanceCode?: string },
) {
  const { data } = await api.put<UserAccountAdminRow>(
    `/v1/admin/user-accounts/${userId}/identifiers`,
    body,
  );
  return data;
}

export async function setDirectorApprovalEnabled(userId: number, enabled: boolean) {
  const { data } = await api.put<UserAccountAdminRow>(
    `/v1/admin/user-accounts/${userId}/director-approval`,
    { enabled },
  );
  return data;
}

export async function setReportViewEnabled(userId: number, enabled: boolean) {
  const { data } = await api.put<UserAccountAdminRow>(
    `/v1/admin/user-accounts/${userId}/report-view`,
    { enabled },
  );
  return data;
}

export async function setWorkUnitScoped(userId: number, enabled: boolean) {
  const { data } = await api.put<UserAccountAdminRow>(
    `/v1/admin/user-accounts/${userId}/work-unit-scope`,
    { enabled },
  );
  return data;
}

export async function resetUserAccountPassword(userId: number) {
  const { data } = await api.post<UserAccountAdminRow>(`/v1/admin/user-accounts/${userId}/reset-password`);
  return data;
}

export async function grantLocalUserAccount(body: {
  employeeId: number;
  role?: string;
  password?: string;
  phone?: string;
  attendanceCode?: string;
}) {
  const { data } = await api.post<UserAccountAdminRow>('/v1/admin/user-accounts/grant', body);
  return data;
}
