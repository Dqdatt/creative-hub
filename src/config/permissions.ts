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
  | 'user_management:update';

export interface NavigationItem {
  id: 'dashboard' | 'calendar' | 'tasks' | 'content_plan' | 'users';
  label: string;
  to: string;
  permission?: Permission;
}

export type ContentPlanField = 'air_date' | 'video_name' | 'category' | 'editor_id';

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
  ],
  editor: [
    'dashboard:view',
    'video_tasks:view',
    'video_tasks:create',
    'video_tasks:update',
    'video_tasks:delete',
    'shoots:view',
    'content_plan:view',
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

const ROUTE_PERMISSIONS: Record<string, Permission | null> = {
  '/dashboard': 'dashboard:view',
  '/calendar': 'shoots:view',
  '/tasks': 'video_tasks:view',
  '/content-plan': 'content_plan:view',
  '/users': 'user_management:view',
  '/profile': null,
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

export function canAccessRoute(role: AppRole | string | null | undefined, route: string) {
  const cleanRoute = route.split('?')[0] || '/dashboard';
  const permission = ROUTE_PERMISSIONS[cleanRoute];

  if (permission === undefined) return true;
  if (permission === null) return true;

  return hasPermission(role, permission);
}

export function getDefaultRoute(role: AppRole | string | null | undefined) {
  const normalizedRole = normalizeRole(role);
  if (normalizedRole === 'content_creator') return '/content-plan';
  return '/dashboard';
}

export const getDefaultRouteForRole = getDefaultRoute;

export function getVisibleNavigation(role: AppRole | string | null | undefined) {
  return NAVIGATION.filter((item) => !item.permission || hasPermission(role, item.permission));
}

export function canEditShoot(role: AppRole | string | null | undefined) {
  return hasPermission(role, 'shoots:create')
    && hasPermission(role, 'shoots:update')
    && hasPermission(role, 'shoots:delete');
}

export function canManageUsers(role: AppRole | string | null | undefined) {
  return hasPermission(role, 'user_management:view')
    && hasPermission(role, 'user_management:create')
    && hasPermission(role, 'user_management:update');
}

export function canEditContentPlanField(
  role: AppRole | string | null | undefined,
  field: ContentPlanField
) {
  const normalizedRole = normalizeRole(role);

  if (normalizedRole === 'admin') return true;
  if (normalizedRole === 'creative_manager') return field === 'editor_id';
  if (normalizedRole === 'content_creator') return field !== 'editor_id';

  return false;
}
