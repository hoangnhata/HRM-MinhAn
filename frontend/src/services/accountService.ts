import api from './api';

export type AccountMe = {
  userId: number;
  username: string;
  email: string;
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
};

export async function fetchAccountMe() {
  const { data } = await api.get<AccountMe>('/v1/account/me');
  return data;
}

export type AccountProfilePayload = {
  email?: string;
  phone?: string;
  address?: string;
  fullName?: string;
  departmentId?: number;
};

export async function updateAccount(payload: AccountProfilePayload) {
  const { data } = await api.patch<AccountMe>('/v1/account/me', payload);
  return data;
}

export async function changeAccountPassword(payload: { oldPassword: string; newPassword: string }) {
  await api.post('/v1/account/change-password', payload);
}
