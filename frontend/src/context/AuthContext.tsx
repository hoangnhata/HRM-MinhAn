import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import * as accountService from '../services/accountService';
import * as authService from '../services/authService';
import { clearAuth, getStoredUser, getToken, setAuth, StoredUser } from '../utils/storage';
import { handleSessionFailure, isSessionFailure } from '../utils/sessionFailure';

type AuthState = {
  token: string | null;
  user: StoredUser | null;
  sessionReady: boolean;
  login: (u: string, p: string) => Promise<void>;
  logout: () => void;
  refreshUser: () => Promise<void>;
};

const AuthContext = createContext<AuthState | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [token, setToken] = useState<string | null>(() => getToken());
  const [user, setUser] = useState<StoredUser | null>(() => getStoredUser());
  const [sessionReady, setSessionReady] = useState(() => !getToken());

  useEffect(() => {
    const onExpired = () => {
      setToken(null);
      setUser(null);
      setSessionReady(true);
    };
    window.addEventListener('minhan:session-expired', onExpired);
    return () => window.removeEventListener('minhan:session-expired', onExpired);
  }, []);

  useEffect(() => {
    const t = getToken();
    if (!t) {
      setSessionReady(true);
      return;
    }

    let cancelled = false;
    (async () => {
      try {
        const a = await accountService.fetchAccountMe();
        if (cancelled) return;
        const prev = getStoredUser();
        if (!prev) {
          handleSessionFailure();
          return;
        }
        const next: StoredUser = {
          ...prev,
          fullName: a.fullName,
          email: a.email,
          role: a.role,
          employeeId: a.employeeId,
          mustChangePassword: a.mustChangePassword,
        };
        setAuth(t, next);
        setUser(next);
      } catch (err) {
        if (!cancelled && isSessionFailure(err)) {
          handleSessionFailure();
          return;
        }
      } finally {
        if (!cancelled) setSessionReady(true);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, []);

  const login = useCallback(async (username: string, password: string) => {
    const res = await authService.login({ username, password });
    const su: StoredUser = {
      username,
      role: res.role,
      employeeId: res.employeeId,
      fullName: res.fullName,
      ...(res.email ? { email: res.email } : {}),
      mustChangePassword: res.mustChangePassword,
    };
    setAuth(res.accessToken, su);
    setToken(res.accessToken);
    setUser(su);
    setSessionReady(true);
  }, []);

  const logout = useCallback(() => {
    clearAuth();
    setToken(null);
    setUser(null);
    setSessionReady(true);
  }, []);

  const refreshUser = useCallback(async () => {
    const t = getToken();
    const prev = getStoredUser();
    if (!t || !prev) return;
    try {
      const a = await accountService.fetchAccountMe();
      const next: StoredUser = {
        ...prev,
        fullName: a.fullName,
        email: a.email,
        role: a.role,
        employeeId: a.employeeId,
        mustChangePassword: a.mustChangePassword,
      };
      setAuth(t, next);
      setUser(next);
    } catch (err) {
      if (isSessionFailure(err)) {
        handleSessionFailure();
      }
    }
  }, []);

  const value = useMemo(
    () => ({
      token,
      user,
      sessionReady,
      login,
      logout,
      refreshUser,
    }),
    [token, user, sessionReady, login, logout, refreshUser]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth outside AuthProvider');
  return ctx;
}
