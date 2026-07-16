export type AppRole = 'admin' | 'creative_manager' | 'content_creator' | 'editor';

export type Permission =
  | 'dashboard:view'
  | 'video_tasks:view'
  | 'video_tasks:create'
  | 'video_tasks:update'
  | 'video_tasks:delete'
  | 'shoots:view'
  | 'shoots:create'
  | 'shoots:update'
  | 'shoots:delete'
  | 'content_plan:view'
  | 'content_plan:create'
  | 'content_plan:update'
  | 'content_plan:assign'
  | 'content_plan:delete'
  | 'user_management:view'
  | 'user_management:create'
  | 'user_management:update'
  | 'profile:edit_self';

export type PermissionAccessMode = 'role_default' | 'view_only' | 'custom';

export type PermissionOverrideKey =
  | 'dashboard_view'
  | 'calendar_view'
  | 'calendar_edit'
  | 'tasks_view'
  | 'tasks_edit'
  | 'content_plan_view'
  | 'content_plan_edit_content'
  | 'content_plan_assign_editor'
  | 'users_manage'
  | 'profile_edit_self';

export type PermissionOverrideFlags = Partial<Record<PermissionOverrideKey, boolean | null>>;

export interface UserPermissionOverride {
  accessMode: PermissionAccessMode;
  flags: PermissionOverrideFlags;
}

export type EffectivePermissions = Record<Permission, boolean>;
export type AppRoute = '/dashboard' | '/calendar' | '/tasks' | '/content-plan' | '/users' | '/profile';

export interface NavigationItem {
  id: 'dashboard' | 'calendar' | 'tasks' | 'content_plan' | 'users';
  label: string;
  to: AppRoute;
  permission?: Permission;
}

export type ContentPlanField = 'air_date' | 'video_name' | 'note' | 'category' | 'editor_id' | 'link';

export const DEFAULT_AUTHENTICATED_ROUTE: AppRoute = '/dashboard';
const FALLBACK_AUTHENTICATED_ROUTE: AppRoute = '/profile';

const ALL_PERMISSIONS: Permission[] = [
  'dashboard:view',
  'video_tasks:view',
  'video_tasks:create',
  'video_tasks:update',
  'video_tasks:delete',
  'shoots:view',
  'shoots:create',
  'shoots:update',
  'shoots:delete',
  'content_plan:view',
  'content_plan:create',
  'content_plan:update',
  'content_plan:assign',
  'content_plan:delete',
  'user_management:view',
  'user_management:create',
  'user_management:update',
  'profile:edit_self',
];

const ROLE_PERMISSIONS: Record<AppRole, Permission[]> = {
  admin: ALL_PERMISSIONS,
  creative_manager: [
    'dashboard:view',
    'video_tasks:view',
    'video_tasks:create',
    'video_tasks:update',
    'video_tasks:delete',
    'shoots:view',
    'shoots:create',
    'shoots:update',
    'shoots:delete',
    'content_plan:view',
    'content_plan:assign',
    'profile:edit_self',
  ],
  content_creator: [
    'shoots:view',
    'shoots:create',
    'shoots:update',
    'shoots:delete',
    'content_plan:view',
    'content_plan:create',
    'content_plan:update',
    'content_plan:delete',
    'profile:edit_self',
  ],
  editor: [
    'dashboard:view',
    'video_tasks:view',
    'video_tasks:create',
    'video_tasks:update',
    'video_tasks:delete',
    'shoots:view',
    'content_plan:view',
    'profile:edit_self',
  ],
};

export const ROLE_LABELS: Record<AppRole, string> = {
  admin: 'Quản trị viên',
  creative_manager: 'Creative Manager',
  content_creator: 'Content Creator',
  editor: 'Editor',
};

const NAVIGATION: NavigationItem[] = [
  { id: 'dashboard', label: 'Tổng quan', to: '/dashboard', permission: 'dashboard:view' },
  { id: 'calendar', label: 'Lịch quay', to: '/calendar', permission: 'shoots:view' },
  { id: 'tasks', label: 'Video tháng', to: '/tasks', permission: 'video_tasks:view' },
  { id: 'content_plan', label: 'Content Plan', to: '/content-plan', permission: 'content_plan:view' },
  { id: 'users', label: 'Thành viên', to: '/users', permission: 'user_management:view' },
];

const ROUTE_PERMISSIONS: Record<AppRoute, Permission | null> = {
  '/dashboard': 'dashboard:view',
  '/calendar': 'shoots:view',
  '/tasks': 'video_tasks:view',
  '/content-plan': 'content_plan:view',
  '/users': 'user_management:view',
  '/profile': null,
};

const ROLE_DEFAULT_ROUTE_ORDER: Record<AppRole, AppRoute[]> = {
  admin: ['/dashboard'],
  creative_manager: ['/dashboard'],
  content_creator: ['/calendar', '/content-plan'],
  editor: ['/dashboard'],
};

export function normalizeRole(role: string | null | undefined): AppRole {
  switch (role) {
    case 'admin':
    case 'creative_manager':
    case 'content_creator':
    case 'editor':
      return role;
    case 'team_lead':
      return 'creative_manager';
    default:
      return 'editor';
  }
}

export function hasPermission(role: AppRole | string | null | undefined, permission: Permission) {
  const normalizedRole = normalizeRole(role);
  return ROLE_PERMISSIONS[normalizedRole].includes(permission);
}

function permissionEntries(permissions: Permission[]) {
  return Object.fromEntries(
    ALL_PERMISSIONS.map((permission) => [permission, permissions.includes(permission)])
  ) as EffectivePermissions;
}

function rolePermissions(role: AppRole | string | null | undefined) {
  return permissionEntries(ROLE_PERMISSIONS[normalizeRole(role)]);
}

function setVideoTaskEditPermissions(permissions: EffectivePermissions, enabled: boolean) {
  permissions['video_tasks:create'] = enabled;
  permissions['video_tasks:update'] = enabled;
  permissions['video_tasks:delete'] = enabled;
}

function setShootEditPermissions(permissions: EffectivePermissions, enabled: boolean) {
  permissions['shoots:create'] = enabled;
  permissions['shoots:update'] = enabled;
  permissions['shoots:delete'] = enabled;
}

function setContentPlanContentPermissions(permissions: EffectivePermissions, enabled: boolean) {
  permissions['content_plan:create'] = enabled;
  permissions['content_plan:update'] = enabled;
  permissions['content_plan:delete'] = enabled;
}

function setUserManagePermissions(permissions: EffectivePermissions, enabled: boolean) {
  permissions['user_management:view'] = enabled;
  permissions['user_management:create'] = enabled;
  permissions['user_management:update'] = enabled;
}

export function getEffectivePermissions(
  role: AppRole | string | null | undefined,
  override?: UserPermissionOverride | null
) {
  const normalizedRole = normalizeRole(role);
  const permissions = rolePermissions(normalizedRole);

  if (!override || override.accessMode === 'role_default') {
    return permissions;
  }

  if (override.accessMode === 'view_only') {
    setVideoTaskEditPermissions(permissions, false);
    setShootEditPermissions(permissions, false);
    setContentPlanContentPermissions(permissions, false);
    permissions['content_plan:assign'] = false;
    setUserManagePermissions(permissions, false);
    permissions['profile:edit_self'] = false;
    return permissions;
  }

  const flags = override.flags;

  permissions['dashboard:view'] = Boolean(flags.dashboard_view);

  permissions['shoots:view'] = Boolean(flags.calendar_view);
  setShootEditPermissions(permissions, Boolean(flags.calendar_edit));
  if (permissions['shoots:create'] || permissions['shoots:update'] || permissions['shoots:delete']) {
    permissions['shoots:view'] = true;
  }

  permissions['video_tasks:view'] = Boolean(flags.tasks_view);
  setVideoTaskEditPermissions(permissions, Boolean(flags.tasks_edit));
  if (permissions['video_tasks:create'] || permissions['video_tasks:update'] || permissions['video_tasks:delete']) {
    permissions['video_tasks:view'] = true;
  }

  permissions['content_plan:view'] = Boolean(flags.content_plan_view);
  setContentPlanContentPermissions(permissions, Boolean(flags.content_plan_edit_content));
  permissions['content_plan:assign'] = Boolean(flags.content_plan_assign_editor);
  if (
    permissions['content_plan:create'] ||
    permissions['content_plan:update'] ||
    permissions['content_plan:delete'] ||
    permissions['content_plan:assign']
  ) {
    permissions['content_plan:view'] = true;
  }

  setUserManagePermissions(permissions, normalizedRole === 'admin');
  permissions['profile:edit_self'] = flags.profile_edit_self !== false;

  return permissions;
}

export function hasEffectivePermission(
  permissions: EffectivePermissions | null | undefined,
  permission: Permission,
  role?: AppRole | string | null
) {
  if (permissions) return permissions[permission] === true;
  return hasPermission(role, permission);
}

function canAccessKnownRoute(
  role: AppRole | string | null | undefined,
  route: AppRoute,
  permissions?: EffectivePermissions | null
) {
  const permission = ROUTE_PERMISSIONS[route];
  if (permission === null) return true;
  return hasEffectivePermission(permissions, permission, role);
}

export function getDefaultAuthenticatedRoute(
  role?: AppRole | string | null,
  permissions?: EffectivePermissions | null
): AppRoute {
  const normalizedRole = normalizeRole(role);
  const preferredRoute = ROLE_DEFAULT_ROUTE_ORDER[normalizedRole].find((route) =>
    canAccessKnownRoute(normalizedRole, route, permissions)
  );

  if (preferredRoute) {
    return preferredRoute;
  }

  if (normalizedRole === 'content_creator') {
    return FALLBACK_AUTHENTICATED_ROUTE;
  }

  return NAVIGATION.find((item) => {
    if (!item.permission) return true;
    return hasEffectivePermission(permissions, item.permission, normalizedRole);
  })?.to ?? FALLBACK_AUTHENTICATED_ROUTE;
}

export function canAccessRoute(
  role: AppRole | string | null | undefined,
  route: string,
  permissions?: EffectivePermissions | null
) {
  const cleanRoute = route.split('?')[0] || getDefaultAuthenticatedRoute(role, permissions);
  if (cleanRoute === '/') return true;

  const permission = ROUTE_PERMISSIONS[cleanRoute as AppRoute];

  if (permission === undefined) return true;
  if (permission === null) return true;

  return hasEffectivePermission(permissions, permission, role);
}

export function getDefaultRoute(
  role?: AppRole | string | null,
  permissions?: EffectivePermissions | null
) {
  return getDefaultAuthenticatedRoute(role, permissions);
}

export const getDefaultRouteForRole = getDefaultAuthenticatedRoute;

export function getVisibleNavigation(role: AppRole | string | null | undefined) {
  return NAVIGATION.filter((item) => !item.permission || hasPermission(role, item.permission));
}

export function getVisibleNavigationForPermissions(
  role: AppRole | string | null | undefined,
  permissions?: EffectivePermissions | null
) {
  return NAVIGATION.filter((item) => !item.permission || hasEffectivePermission(permissions, item.permission, role));
}

export function canEditShoot(role: AppRole | string | null | undefined) {
  return hasPermission(role, 'shoots:create')
    && hasPermission(role, 'shoots:update')
    && hasPermission(role, 'shoots:delete');
}

export function canEditShootWithPermissions(
  role: AppRole | string | null | undefined,
  permissions?: EffectivePermissions | null
) {
  return hasEffectivePermission(permissions, 'shoots:create', role)
    && hasEffectivePermission(permissions, 'shoots:update', role)
    && hasEffectivePermission(permissions, 'shoots:delete', role);
}

export function canManageUsers(role: AppRole | string | null | undefined) {
  return hasPermission(role, 'user_management:view')
    && hasPermission(role, 'user_management:create')
    && hasPermission(role, 'user_management:update');
}

export function canManageUsersWithPermissions(
  role: AppRole | string | null | undefined,
  permissions?: EffectivePermissions | null
) {
  return hasEffectivePermission(permissions, 'user_management:view', role)
    && hasEffectivePermission(permissions, 'user_management:create', role)
    && hasEffectivePermission(permissions, 'user_management:update', role);
}

export function canEditContentPlanField(
  role: AppRole | string | null | undefined,
  field: ContentPlanField,
  permissions?: EffectivePermissions | null
) {
  const normalizedRole = normalizeRole(role);
  const canEditContent = hasEffectivePermission(permissions, 'content_plan:update', normalizedRole);
  const canAssignEditor = hasEffectivePermission(permissions, 'content_plan:assign', normalizedRole);

  if (field === 'editor_id') return canAssignEditor || (normalizedRole === 'admin' && canEditContent);
  return canEditContent;
}

export function getPermissionOverrideSummary(mode: PermissionAccessMode) {
  if (mode === 'view_only') return 'Chỉ xem';
  if (mode === 'custom') return 'Tùy chỉnh';
  return 'Theo vai trò';
}
