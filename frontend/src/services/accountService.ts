import api from './api';

export type AccountMe = {
  userId: number;
  username: string;
  email: string;
  /** Vai trò HRM — không dùng roles ERP */
  role: string;
  fullName: string;
  employeeId: number | null;
  enabled: boolean;
  directorApprovalEnabled?: boolean;
  /** true = được xem báo cáo nhân lực (cấp bởi Admin). */
  reportViewEnabled?: boolean;
  /** true = trưởng khoa chỉ quản lý bộ phận (workUnitDetail) của mình. */
  workUnitScoped?: boolean;
  mustChangePassword?: boolean;
  createdAt: string;
  phone: string | null;
  address: string | null;
  departmentName: string | null;
  departmentId: number | null;
  positionTitle?: string | null;
  /** Bộ phận (workUnitDetail) — khác Phòng ban */
  workUnitDetail?: string | null;
  erpLinked?: boolean;
  dateOfBirth?: string | null;
  userAvatar?: string | null;
  userEnrollNumber?: number | null;
  /** Mã nhân viên HRM — thường là số CCCD/CMND. */
  employeeCode?: string | null;
  hasSignature?: boolean;
  signatureUrl?: string | null;
  hasAvatar?: boolean;
  /** false khi NV thử việc chưa có ngày vào làm chính thức */
  canViewSalary?: boolean;
  employeeStatus?: string | null;
};

export async function fetchAccountMe() {
  const { data } = await api.get<AccountMe>('/v1/account/me');
  return data;
}

/** Tải avatar (local hoặc ERP) qua proxy (có Bearer) → blob URL. */
export async function fetchAccountAvatarObjectUrl(userId?: number | null): Promise<string | null> {
  try {
    const { data } = await api.get<Blob>('/v1/account/me/avatar', {
      responseType: 'blob',
      params: {
        _: userId ?? Date.now(),
      },
      headers: {
        'Cache-Control': 'no-cache',
        Pragma: 'no-cache',
      },
    });
    if (!data || data.size === 0 || (data.type && data.type.includes('json'))) {
      return null;
    }
    return URL.createObjectURL(data);
  } catch {
    return null;
  }
}

export async function saveMyAvatar(imageBase64: string) {
  const { data } = await api.put<AccountMe>('/v1/account/me/avatar', { imageBase64 });
  return data;
}

export async function deleteMyAvatar() {
  const { data } = await api.delete<AccountMe>('/v1/account/me/avatar');
  return data;
}

export async function fetchMySignatureObjectUrl(): Promise<string | null> {
  try {
    const { data } = await api.get<Blob>('/v1/account/me/signature', {
      responseType: 'blob',
      params: { _: Date.now() },
      headers: { 'Cache-Control': 'no-cache', Pragma: 'no-cache' },
    });
    if (!data || data.size === 0 || (data.type && data.type.includes('json'))) {
      return null;
    }
    return URL.createObjectURL(data);
  } catch {
    return null;
  }
}

export async function saveMySignature(imageBase64: string) {
  const { data } = await api.put<AccountMe>('/v1/account/me/signature', { imageBase64 });
  return data;
}

export async function deleteMySignature() {
  const { data } = await api.delete<AccountMe>('/v1/account/me/signature');
  return data;
}

export type AccountProfilePayload = {
  email?: string;
  phone?: string;
  address?: string;
  fullName?: string;
  departmentId?: number;
  dateOfBirth?: string;
  userAvatar?: string;
};

export async function updateAccount(payload: AccountProfilePayload) {
  const { data } = await api.patch<AccountMe>('/v1/account/me', payload);
  return data;
}

export async function changeAccountPassword(payload: { oldPassword: string; newPassword: string }) {
  await api.post('/v1/account/change-password', payload);
}
