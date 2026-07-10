import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type { ReactNode } from 'react';
import type { AuthChangeEvent, AuthError, Session, User } from '@supabase/supabase-js';
import {
  getEffectivePermissions,
  hasEffectivePermission,
  normalizeRole,
  ROLE_LABELS,
} from '../config/permissions';
import type { Permission, UserPermissionOverride } from '../config/permissions';
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

const DEFAULT_PERMISSION_OVERRIDE: UserPermissionOverride = {
  accessMode: 'role_default',
  flags: {},
};

interface PermissionOverrideRow {
  access_mode: 'role_default' | 'view_only' | 'custom' | null;
  dashboard_view: boolean | null;
  calendar_view: boolean | null;
  calendar_edit: boolean | null;
  tasks_view: boolean | null;
  tasks_edit: boolean | null;
  content_plan_view: boolean | null;
  content_plan_edit_content: boolean | null;
  content_plan_assign_editor: boolean | null;
  users_manage: boolean | null;
  profile_edit_self: boolean | null;
}

function isMissingOverrideTable(error: { code?: string; message?: string } | null) {
  const message = (error?.message ?? '').toLowerCase();
  return error?.code === '42P01' ||
    error?.code === 'PGRST205' ||
    message.includes('user_permission_overrides') ||
    message.includes('could not find the table');
}

function mapOverrideRow(row: PermissionOverrideRow | null): UserPermissionOverride {
  if (!row) return DEFAULT_PERMISSION_OVERRIDE;

  return {
    accessMode: row.access_mode ?? 'role_default',
    flags: {
      dashboard_view: row.dashboard_view,
      calendar_view: row.calendar_view,
      calendar_edit: row.calendar_edit,
      tasks_view: row.tasks_view,
      tasks_edit: row.tasks_edit,
      content_plan_view: row.content_plan_view,
      content_plan_edit_content: row.content_plan_edit_content,
      content_plan_assign_editor: row.content_plan_assign_editor,
      users_manage: row.users_manage,
      profile_edit_self: row.profile_edit_self,
    },
  };
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);
  const [profileLoading, setProfileLoading] = useState(false);
  const [backgroundAuthRefreshing, setBackgroundAuthRefreshing] = useState(false);
  const [authError, setAuthError] = useState<string | null>(mapConfigError(supabaseConfigError));
  const [profileError, setProfileError] = useState<string | null>(null);
  const [profile, setProfile] = useState<AuthProfile | null>(null);
  const [permissionOverride, setPermissionOverride] = useState<UserPermissionOverride>(DEFAULT_PERMISSION_OVERRIDE);
  const sessionRef = useRef<Session | null>(null);
  const profileRequestIdRef = useRef(0);
  const authEventRequestIdRef = useRef(0);
  const initialProfileResolvedRef = useRef(false);

  const markInitialProfileResolved = useCallback(() => {
    initialProfileResolvedRef.current = true;
  }, []);

  const applySession = useCallback((nextSession: Session | null) => {
    sessionRef.current = nextSession;
    setSession(nextSession);
  }, []);

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

  const loadProfileForUser = useCallback(async (
    currentUser: User | null | undefined,
    options?: { silent?: boolean },
  ) => {
    const requestId = profileRequestIdRef.current + 1;
    profileRequestIdRef.current = requestId;
    const isInitialProfileLoad = !initialProfileResolvedRef.current;
    const showInitialProfileGate = isInitialProfileLoad && !options?.silent;

    if (!currentUser) {
      setProfile(null);
      setProfileError(null);
      setPermissionOverride(DEFAULT_PERMISSION_OVERRIDE);
      setProfileLoading(false);
      setBackgroundAuthRefreshing(false);
      markInitialProfileResolved();
      return;
    }

    if (!supabase) {
      setProfile(buildFallbackProfile(currentUser));
      setProfileError('Không thể tải hồ sơ. Tạm dùng quyền Editor.');
      setPermissionOverride(DEFAULT_PERMISSION_OVERRIDE);
      setProfileLoading(false);
      setBackgroundAuthRefreshing(false);
      markInitialProfileResolved();
      return;
    }

    if (showInitialProfileGate) {
      setProfileLoading(true);
    } else {
      setBackgroundAuthRefreshing(true);
    }
    setProfileError(null);

    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('id, email, full_name, display_name, short_name, role, avatar_url, department, active, is_active')
        .eq('id', currentUser.id)
        .maybeSingle();

      if (error) throw error;
      if (requestId !== profileRequestIdRef.current) return;

      if (!data) {
        await supabase.auth.signOut();
        applySession(null);
        setProfile(null);
        setPermissionOverride(DEFAULT_PERMISSION_OVERRIDE);
        setProfileError('Tài khoản không còn hoạt động. Vui lòng đăng nhập lại.');
        return;
      }

      if ((data.is_active ?? data.active ?? true) === false) {
        await supabase.auth.signOut();
        applySession(null);
        setProfile(null);
        setPermissionOverride(DEFAULT_PERMISSION_OVERRIDE);
        setProfileError('Tài khoản đã bị tạm khóa. Vui lòng liên hệ quản trị viên.');
        return;
      }

      const { data: overrideData, error: overrideError } = await supabase
        .from('user_permission_overrides')
        .select(`
          access_mode,
          dashboard_view,
          calendar_view,
          calendar_edit,
          tasks_view,
          tasks_edit,
          content_plan_view,
          content_plan_edit_content,
          content_plan_assign_editor,
          users_manage,
          profile_edit_self
        `)
        .eq('profile_id', currentUser.id)
        .maybeSingle();

      if (overrideError && !isMissingOverrideTable(overrideError)) throw overrideError;
      if (requestId !== profileRequestIdRef.current) return;

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
      setPermissionOverride(mapOverrideRow((overrideData ?? null) as PermissionOverrideRow | null));
    } catch {
      if (requestId !== profileRequestIdRef.current) return;
      setProfile(buildFallbackProfile(currentUser));
      setPermissionOverride(DEFAULT_PERMISSION_OVERRIDE);
      setProfileError('Không thể tải hồ sơ người dùng. Tạm dùng quyền Editor.');
    } finally {
      if (requestId === profileRequestIdRef.current) {
        markInitialProfileResolved();
        setProfileLoading(false);
        setBackgroundAuthRefreshing(false);
      }
    }
  }, [applySession, buildFallbackProfile, markInitialProfileResolved]);

  const refreshProfile = useCallback(async () => {
    await loadProfileForUser(sessionRef.current?.user, { silent: true });
  }, [loadProfileForUser]);

  const handleAuthEvent = useCallback(async (event: AuthChangeEvent, nextSession: Session | null) => {
    if (import.meta.env.DEV) {
      console.info(`[Auth] ${event}`);
    }

    const requestId = authEventRequestIdRef.current + 1;
    authEventRequestIdRef.current = requestId;
    const previousSession = sessionRef.current;
    const previousUserId = previousSession?.user.id;
    const nextUserId = nextSession?.user.id;
    const sameAuthenticatedUser = Boolean(previousUserId && nextUserId && previousUserId === nextUserId);

    if (!nextSession) {
      applySession(null);
      setProfile(null);
      setPermissionOverride(DEFAULT_PERMISSION_OVERRIDE);
      setProfileError(null);
      setProfileLoading(false);
      setBackgroundAuthRefreshing(false);
      markInitialProfileResolved();
      setLoading(false);
      return;
    }

    applySession(nextSession);
    setAuthError(null);

    if (
      sameAuthenticatedUser &&
      initialProfileResolvedRef.current &&
      (event === 'TOKEN_REFRESHED' || event === 'SIGNED_IN')
    ) {
      setBackgroundAuthRefreshing(false);
      setLoading(false);
      return;
    }

    const isSilentProfileRefresh = initialProfileResolvedRef.current ||
      event === 'TOKEN_REFRESHED' ||
      (sameAuthenticatedUser && event === 'USER_UPDATED');

    await loadProfileForUser(nextSession.user, { silent: isSilentProfileRefresh });
    if (requestId !== authEventRequestIdRef.current) return;
    setLoading(false);
  }, [applySession, loadProfileForUser, markInitialProfileResolved]);

  useEffect(() => {
    if (!supabase) {
      setLoading(false);
      markInitialProfileResolved();
      return;
    }

    let mounted = true;

    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, nextSession) => {
      if (!mounted) return;
      void handleAuthEvent(event, nextSession);
    });

    return () => {
      mounted = false;
      subscription.unsubscribe();
    };
  }, [handleAuthEvent, markInitialProfileResolved]);

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
      applySession(null);
      return { error: mappedError };
    }

    applySession(data.session);
    await loadProfileForUser(data.session?.user, { silent: true });
    return { error: null };
  }, [applySession, loadProfileForUser]);

  const signOut = useCallback(async () => {
    if (!supabase) {
      applySession(null);
      return { error: null };
    }

    const { error } = await supabase.auth.signOut();
    if (error) {
      const mappedError = mapAuthError(error);
      setAuthError(mappedError);
      return { error: mappedError };
    }

    applySession(null);
    setProfile(null);
    setPermissionOverride(DEFAULT_PERMISSION_OVERRIDE);
    setProfileError(null);
    setProfileLoading(false);
    setBackgroundAuthRefreshing(false);
    setAuthError(null);
    return { error: null };
  }, [applySession]);

  const clearAuthError = useCallback(() => {
    setAuthError(mapConfigError(supabaseConfigError));
  }, []);

  const permissions = useMemo(
    () => getEffectivePermissions(profile?.role ?? 'editor', permissionOverride),
    [permissionOverride, profile?.role]
  );

  const can = useCallback((permission: Permission) => (
    hasEffectivePermission(permissions, permission, profile?.role ?? 'editor')
  ), [permissions, profile?.role]);

  const value = useMemo<AuthContextValue>(() => ({
    session,
    user: session?.user ?? null,
    loading,
    profileLoading,
    backgroundAuthRefreshing,
    authError,
    profileError,
    configError: mapConfigError(supabaseConfigError),
    profile,
    role: profile?.role ?? 'editor',
    roleLabel: ROLE_LABELS[profile?.role ?? 'editor'],
    permissionOverride,
    permissionMode: permissionOverride.accessMode,
    permissions,
    can,
    signIn,
    signOut,
    clearAuthError,
    refreshProfile,
  }), [authError, backgroundAuthRefreshing, can, clearAuthError, loading, permissionOverride, permissions, profile, profileError, profileLoading, refreshProfile, session, signIn, signOut]);

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
}
