import React, { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react';
import * as accountService from '../services/accountService';
import * as authService from '../services/authService';
import { clearAuth, getStoredUser, getToken, setAuth, StoredUser } from '../utils/storage';
import { handleSessionFailure, isSessionFailure } from '../utils/sessionFailure';

type AuthState = {
  token: string | null;
  user: StoredUser | null;
  /** Ảnh đại diện ERP (blob/data URL) — dùng header + trang cá nhân */
  avatarUrl: string | null;
  sessionReady: boolean;
  login: (u: string, p: string) => Promise<void>;
  logout: () => void;
  refreshUser: () => Promise<void>;
};

const AuthContext = createContext<AuthState | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [token, setToken] = useState<string | null>(() => getToken());
  const [user, setUser] = useState<StoredUser | null>(() => getStoredUser());
  const [avatarUrl, setAvatarUrl] = useState<string | null>(null);
  const [sessionReady, setSessionReady] = useState(() => !getToken());
  const avatarObjectUrlRef = useRef<string | null>(null);
  /** Tăng mỗi lần đổi phiên — bỏ kết quả tải avatar cũ (tránh dính ảnh user trước). */
  const avatarLoadGenRef = useRef(0);

  const clearAvatar = useCallback(() => {
    avatarLoadGenRef.current += 1;
    if (avatarObjectUrlRef.current) {
      URL.revokeObjectURL(avatarObjectUrlRef.current);
      avatarObjectUrlRef.current = null;
    }
    setAvatarUrl(null);
  }, []);

  const loadAvatar = useCallback(async (me: accountService.AccountMe) => {
    const gen = ++avatarLoadGenRef.current;
    const applyIfCurrent = (url: string | null) => {
      if (gen !== avatarLoadGenRef.current) {
        if (url && url.startsWith('blob:')) URL.revokeObjectURL(url);
        return;
      }
      if (avatarObjectUrlRef.current) {
        URL.revokeObjectURL(avatarObjectUrlRef.current);
        avatarObjectUrlRef.current = null;
      }
      if (url && url.startsWith('blob:')) {
        avatarObjectUrlRef.current = url;
      }
      setAvatarUrl(url);
    };

    if (!me.erpLinked || !me.userAvatar) {
      applyIfCurrent(null);
      return;
    }
    if (me.userAvatar.startsWith('data:image')) {
      applyIfCurrent(me.userAvatar);
      return;
    }
    const url = await accountService.fetchAccountAvatarObjectUrl(me.userId);
    if (gen !== avatarLoadGenRef.current) {
      if (url) URL.revokeObjectURL(url);
      return;
    }
    applyIfCurrent(url);
  }, []);

  useEffect(() => {
    const onExpired = () => {
      clearAvatar();
      setToken(null);
      setUser(null);
      setSessionReady(true);
    };
    window.addEventListener('minhan:session-expired', onExpired);
    return () => window.removeEventListener('minhan:session-expired', onExpired);
  }, [clearAvatar]);

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
        await loadAvatar(a);
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
  }, [loadAvatar]);

  useEffect(() => {
    return () => {
      if (avatarObjectUrlRef.current) {
        URL.revokeObjectURL(avatarObjectUrlRef.current);
        avatarObjectUrlRef.current = null;
      }
    };
  }, []);

  const login = useCallback(async (username: string, password: string) => {
    clearAvatar();
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
    try {
      const a = await accountService.fetchAccountMe();
      const next: StoredUser = {
        ...su,
        fullName: a.fullName || su.fullName,
        email: a.email || su.email,
        role: a.role || su.role,
        employeeId: a.employeeId,
        mustChangePassword: a.mustChangePassword,
      };
      setAuth(res.accessToken, next);
      setUser(next);
      await loadAvatar(a);
    } catch {
      clearAvatar();
    }
  }, [clearAvatar, loadAvatar]);

  const logout = useCallback(() => {
    clearAuth();
    clearAvatar();
    setToken(null);
    setUser(null);
    setSessionReady(true);
  }, [clearAvatar]);

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
      await loadAvatar(a);
    } catch (err) {
      if (isSessionFailure(err)) {
        handleSessionFailure();
      }
    }
  }, [loadAvatar]);

  const value = useMemo(
    () => ({
      token,
      user,
      avatarUrl,
      sessionReady,
      login,
      logout,
      refreshUser,
    }),
    [token, user, avatarUrl, sessionReady, login, logout, refreshUser]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth outside AuthProvider');
  return ctx;
}
