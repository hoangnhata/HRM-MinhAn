import api from './api';

export type LoginBody = { username: string; password: string };

export type LoginResponse = {
  accessToken: string;
  tokenType: string;
  role: string;
  userId: number;
  employeeId: number | null;
  fullName: string;
  email?: string;
  mustChangePassword?: boolean;
};

export async function login(body: LoginBody): Promise<LoginResponse> {
  const { data } = await api.post<LoginResponse>('/auth/login', body);
  return data;
}
