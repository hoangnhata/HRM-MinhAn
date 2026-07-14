import type { AxiosError } from 'axios';
import { clearAuth, getToken } from './storage';

export function isSessionFailure(err: unknown): boolean {
  const token = getToken();
  if (!token) return false;

  const ax = err as AxiosError | undefined;
  if (!ax) return false;

  const status = ax.response?.status;
  if (status === 401) return true;

  if (!ax.response) {
    return ax.code === 'ERR_NETWORK' || ax.message === 'Network Error';
  }

  return false;
}

export function handleSessionFailure(): void {
  clearAuth();
  window.dispatchEvent(new Event('minhan:session-expired'));
  if (!window.location.pathname.startsWith('/login')) {
    window.location.href = '/login';
  }
}
