import React, { createContext, useCallback, useContext, useMemo, useState } from 'react';
import * as accountService from '../services/accountService';
import * as authService from '../services/authService';
import { clearAuth, getStoredUser, getToken, setAuth, StoredUser } from '../utils/storage';

type AuthState = {
  token: string | null;
  user: StoredUser | null;
  login: (u: string, p: string) => Promise<void>;
  logout: () => void;
  refreshUser: () => Promise<void>;
};

const AuthContext = createContext<AuthState | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [token, setToken] = useState<string | null>(() => getToken());
  const [user, setUser] = useState<StoredUser | null>(() => getStoredUser());

  const login = useCallback(async (username: string, password: string) => {
    const res = await authService.login({ username, password });
    const su: StoredUser = {
      username,
      role: res.role,
      employeeId: res.employeeId,
      fullName: res.fullName,
      ...(res.email ? { email: res.email } : {}),
    };
    setAuth(res.accessToken, su);
    setToken(res.accessToken);
    setUser(su);
  }, []);

  const logout = useCallback(() => {
    clearAuth();
    setToken(null);
    setUser(null);
  }, []);

  const refreshUser = useCallback(async () => {
    const t = getToken();
    const prev = getStoredUser();
    if (!t || !prev) return;
    const a = await accountService.fetchAccountMe();
    const next: StoredUser = {
      ...prev,
      fullName: a.fullName,
      email: a.email,
      role: a.role,
    };
    setAuth(t, next);
    setUser(next);
  }, []);

  const value = useMemo(
    () => ({
      token,
      user,
      login,
      logout,
      refreshUser,
    }),
    [token, user, login, logout, refreshUser]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth outside AuthProvider');
  return ctx;
}
