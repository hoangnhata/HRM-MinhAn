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
  mustChangePassword?: boolean;
  createdAt: string;
  phone: string | null;
  address: string | null;
  departmentName: string | null;
  departmentId: number | null;
  erpLinked?: boolean;
  dateOfBirth?: string | null;
  userAvatar?: string | null;
  userEnrollNumber?: number | null;
};

export async function fetchAccountMe() {
  const { data } = await api.get<AccountMe>('/v1/account/me');
  return data;
}

/** Tải avatar ERP qua proxy (có Bearer) → blob URL. cacheBust theo userId để không dính ảnh user khác. */
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
