import { useCallback, useEffect, useMemo, useState } from 'react';
import type { ReactNode } from 'react';
import type { AuthError, Session, User } from '@supabase/supabase-js';
import { normalizeRole, ROLE_LABELS } from '../config/permissions';
import { supabase, supabaseConfigError } from '../lib/supabase';
import { AuthContext } from './authContext';
import type { AuthContextValue, AuthProfile } from './authContext';

function mapAuthError(error: AuthError | Error | null) {
  if (!error) return null;

  const message = error.message.toLowerCase();
  if (message.includes('invalid login credentials')) return 'Email hoặc mật khẩu chưa đúng.';
  if (message.includes('email not confirmed')) return 'Email chưa được xác nhận. Vui lòng kiểm tra hộp thư.';
  if (message.includes('rate limit')) return 'Bạn thao tác quá nhanh. Vui lòng thử lại sau ít phút.';
  if (message.includes('network')) return 'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng.';
  if (message.includes('failed to fetch')) return 'Không thể kết nối máy chủ. Vui lòng thử lại.';

  return 'Đăng nhập không thành công. Vui lòng thử lại.';
}

function mapConfigError(error: string | null) {
  return error ? 'Đăng nhập chưa sẵn sàng. Vui lòng liên hệ quản trị viên.' : null;
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);
  const [profileLoading, setProfileLoading] = useState(false);
  const [authError, setAuthError] = useState<string | null>(mapConfigError(supabaseConfigError));
  const [profileError, setProfileError] = useState<string | null>(null);
  const [profile, setProfile] = useState<AuthProfile | null>(null);

  const buildFallbackProfile = useCallback((user: User): AuthProfile => {
    const fallbackName = typeof user.user_metadata?.full_name === 'string'
      ? user.user_metadata.full_name
      : typeof user.user_metadata?.name === 'string'
        ? user.user_metadata.name
        : user.email?.split('@')[0] ?? 'Nhân sự';

    return {
      id: user.id,
      email: user.email ?? '',
      fullName: fallbackName,
      displayName: fallbackName,
      avatarUrl: typeof user.user_metadata?.avatar_url === 'string' ? user.user_metadata.avatar_url : '',
      department: 'Team Marketing',
      role: 'editor',
      rawRole: null,
    };
  }, []);

  const refreshProfile = useCallback(async () => {
    const currentUser = session?.user;

    if (!currentUser) {
      setProfile(null);
      setProfileError(null);
      setProfileLoading(false);
      return;
    }

    if (!supabase) {
      setProfile(buildFallbackProfile(currentUser));
      setProfileError('Không thể tải hồ sơ. Tạm dùng quyền Editor.');
      setProfileLoading(false);
      return;
    }

    setProfileLoading(true);
    setProfileError(null);

    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('id, email, full_name, display_name, short_name, role, avatar_url, department, active, is_active')
        .eq('id', currentUser.id)
        .maybeSingle();

      if (error) throw error;

      if (!data) {
        await supabase.auth.signOut();
        setSession(null);
        setProfile(null);
        setProfileError('Tài khoản không còn hoạt động. Vui lòng đăng nhập lại.');
        return;
      }

      if ((data.is_active ?? data.active ?? true) === false) {
        await supabase.auth.signOut();
        setSession(null);
        setProfile(null);
        setProfileError('Tài khoản đã bị tạm khóa. Vui lòng liên hệ quản trị viên.');
        return;
      }

      const role = normalizeRole(data.role);
      const fallbackProfile = buildFallbackProfile(currentUser);
      const displayName = data.display_name || data.short_name || data.full_name || fallbackProfile.displayName;

      setProfile({
        id: data.id,
        email: data.email || currentUser.email || '',
        fullName: data.full_name || displayName,
        displayName,
        avatarUrl: data.avatar_url || fallbackProfile.avatarUrl,
        department: data.department || 'Team Marketing',
        role,
        rawRole: data.role,
      });
    } catch {
      setProfile(buildFallbackProfile(currentUser));
      setProfileError('Không thể tải hồ sơ người dùng. Tạm dùng quyền Editor.');
    } finally {
      setProfileLoading(false);
    }
  }, [buildFallbackProfile, session?.user]);

  useEffect(() => {
    if (!supabase) {
      setLoading(false);
      return;
    }

    let mounted = true;

    supabase.auth.getSession()
      .then(({ data, error }) => {
        if (!mounted) return;
        if (error) {
          setAuthError(mapAuthError(error));
          setSession(null);
          return;
        }
        setSession(data.session);
      })
      .catch((error: Error) => {
        if (!mounted) return;
        setAuthError(mapAuthError(error));
        setSession(null);
      })
      .finally(() => {
        if (mounted) setLoading(false);
      });

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession);
      setLoading(false);
      if (!nextSession) {
        setProfile(null);
        setProfileError(null);
        setProfileLoading(false);
      }
      if (nextSession) setAuthError(null);
    });

    return () => {
      mounted = false;
      subscription.unsubscribe();
    };
  }, []);

  useEffect(() => {
    void refreshProfile();
  }, [refreshProfile]);

  const signIn = useCallback(async (email: string, password: string) => {
    if (!supabase) {
      const error = mapConfigError(supabaseConfigError) ?? 'Đăng nhập chưa sẵn sàng.';
      setAuthError(error);
      return { error };
    }

    const cleanEmail = email.trim();
    if (!cleanEmail || !password) {
      const error = 'Vui lòng nhập email và mật khẩu.';
      setAuthError(error);
      return { error };
    }

    setAuthError(null);
    const { data, error } = await supabase.auth.signInWithPassword({
      email: cleanEmail,
      password,
    });

    if (error) {
      const mappedError = mapAuthError(error);
      setAuthError(mappedError);
      setSession(null);
      return { error: mappedError };
    }

    setSession(data.session);
    return { error: null };
  }, []);

  const signOut = useCallback(async () => {
    if (!supabase) {
      setSession(null);
      return { error: null };
    }

    const { error } = await supabase.auth.signOut();
    if (error) {
      const mappedError = mapAuthError(error);
      setAuthError(mappedError);
      return { error: mappedError };
    }

    setSession(null);
    setProfile(null);
    setProfileError(null);
    setProfileLoading(false);
    setAuthError(null);
    return { error: null };
  }, []);

  const clearAuthError = useCallback(() => {
    setAuthError(mapConfigError(supabaseConfigError));
  }, []);

  const value = useMemo<AuthContextValue>(() => ({
    session,
    user: session?.user ?? null,
    loading,
    profileLoading,
    authError,
    profileError,
    configError: mapConfigError(supabaseConfigError),
    profile,
    role: profile?.role ?? 'editor',
    roleLabel: ROLE_LABELS[profile?.role ?? 'editor'],
    signIn,
    signOut,
    clearAuthError,
    refreshProfile,
  }), [authError, clearAuthError, loading, profile, profileError, profileLoading, refreshProfile, session, signIn, signOut]);

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
}
