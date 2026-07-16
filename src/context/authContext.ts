import { createContext, useContext } from 'react';
import type { Session, User } from '@supabase/supabase-js';
import type { AppRole, AppRoute, EffectivePermissions, Permission, PermissionAccessMode, UserPermissionOverride } from '../config/permissions';

export interface AuthProfile {
  id: string;
  email: string;
  fullName: string;
  displayName: string;
  avatarUrl: string;
  department: string;
  role: AppRole;
  rawRole: string | null;
}

export interface AuthContextValue {
  session: Session | null;
  user: User | null;
  loading: boolean;
  profileLoading: boolean;
  backgroundAuthRefreshing: boolean;
  authError: string | null;
  profileError: string | null;
  configError: string | null;
  profile: AuthProfile | null;
  role: AppRole;
  roleLabel: string;
  permissionOverride: UserPermissionOverride;
  permissionMode: PermissionAccessMode;
  permissions: EffectivePermissions;
  can: (permission: Permission) => boolean;
  signIn: (email: string, password: string) => Promise<{ error: string | null; defaultRoute?: AppRoute }>;
  signOut: () => Promise<{ error: string | null }>;
  clearAuthError: () => void;
  refreshProfile: () => Promise<void>;
}

export const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) throw new Error('useAuth must be used inside AuthProvider');
  return context;
}
