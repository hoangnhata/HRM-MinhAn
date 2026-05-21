import api from './api';

export type LoginBody = { username: string; password: string };

export type LoginResponse = {
  accessToken: string;
  tokenType: string;
  role: 'ADMIN' | 'EMPLOYEE';
  userId: number;
  employeeId: number | null;
  fullName: string;
  email?: string;
};

export async function login(body: LoginBody): Promise<LoginResponse> {
  const { data } = await api.post<LoginResponse>('/auth/login', body);
  return data;
}
