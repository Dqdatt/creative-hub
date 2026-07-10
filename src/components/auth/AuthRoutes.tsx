import type { ReactNode } from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { canAccessRoute, getDefaultRouteForRole } from '../../config/permissions';
import { useAuth } from '../../context/authContext';
import { AuthLoading } from './AuthLoading';

interface RouteGateProps {
  children: ReactNode;
}

function getReturnPath(state: unknown, role: string | null | undefined) {
  const defaultRoute = getDefaultRouteForRole(role);
  if (state && typeof state === 'object' && 'from' in state && typeof state.from === 'string') {
    if (state.from === '/login') return defaultRoute;
    return canAccessRoute(role, state.from) ? state.from : defaultRoute;
  }
  return defaultRoute;
}

export function ProtectedRoute({ children }: RouteGateProps) {
  const { user, loading, profileLoading, role } = useAuth();
  const location = useLocation();

  if (loading || profileLoading) return <AuthLoading />;
  if (!user) {
    return (
      <Navigate
        to="/login"
        replace
        state={{ from: `${location.pathname}${location.search}` }}
      />
    );
  }

  if (!canAccessRoute(role, location.pathname)) {
    return <Navigate to={getDefaultRouteForRole(role)} replace />;
  }

  return children;
}

export function PublicOnlyRoute({ children }: RouteGateProps) {
  const { user, loading, profileLoading, role } = useAuth();
  const location = useLocation();

  if (loading || profileLoading) return <AuthLoading />;
  if (user) return <Navigate to={getReturnPath(location.state, role)} replace />;

  return children;
}
