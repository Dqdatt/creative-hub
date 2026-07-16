import type { AppRoute } from '../config/permissions';

const ROUTE_ALIASES: Record<string, AppRoute> = {
  '/calendar': '/calendar',
  '/content-plan': '/content-plan',
  '/tasks': '/tasks',
  '/video-thang': '/tasks',
};

const ROUTE_ALLOWED_PARAMS: Record<AppRoute, ReadonlySet<string>> = {
  '/dashboard': new Set(),
  '/calendar': new Set(['highlight', 'date']),
  '/tasks': new Set(['highlight']),
  '/content-plan': new Set(['highlight']),
  '/users': new Set(),
  '/profile': new Set(),
};

export interface SafeNotificationAction {
  route: AppRoute;
  to: string;
}

export function resolveNotificationActionUrl(value: string | null | undefined): SafeNotificationAction | null {
  const cleanValue = value?.trim();
  if (!cleanValue || !cleanValue.startsWith('/') || cleanValue.startsWith('//')) return null;

  let url: URL;
  try {
    url = new URL(cleanValue, 'https://creativehub.local');
  } catch {
    return null;
  }

  if (url.origin !== 'https://creativehub.local') return null;

  const route = ROUTE_ALIASES[url.pathname];
  if (!route) return null;
  const params = new URLSearchParams(url.search);

  if (route === '/calendar') {
    const oldShootId = params.get('shoot');
    if (oldShootId && !params.has('highlight')) {
      params.set('highlight', oldShootId);
    }
    params.delete('shoot');
  }

  if (route === '/content-plan') {
    const oldItemId = params.get('item');
    if (oldItemId && !params.has('highlight')) {
      params.set('highlight', oldItemId);
    }
    params.delete('item');
  }

  if (route === '/tasks') {
    const oldTaskId = params.get('task');
    if (oldTaskId && !params.has('highlight')) {
      params.set('highlight', oldTaskId);
    }
    params.delete('task');
  }

  const allowedParams = ROUTE_ALLOWED_PARAMS[route];
  for (const key of Array.from(params.keys())) {
    if (!allowedParams.has(key)) params.delete(key);
  }

  const search = params.toString();

  return {
    route,
    to: `${route}${search ? `?${search}` : ''}`,
  };
}
