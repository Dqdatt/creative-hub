import type { ReactNode } from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { canAccessRoute, getDefaultAuthenticatedRoute } from '../../config/permissions';
import { useAuth } from '../../context/authContext';
import { AuthLoading } from './AuthLoading';

interface RouteGateProps {
  children: ReactNode;
}

export function ProtectedRoute({ children }: RouteGateProps) {
  const { user, loading, profileLoading, role, permissions } = useAuth();
  const location = useLocation();
  const defaultRoute = getDefaultAuthenticatedRoute(role, permissions);

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

  if (!canAccessRoute(role, location.pathname, permissions)) {
    return <Navigate to={defaultRoute} replace />;
  }

  return children;
}

export function PublicOnlyRoute({ children }: RouteGateProps) {
  const { user, loading, profileLoading, role, permissions } = useAuth();
  const defaultRoute = getDefaultAuthenticatedRoute(role, permissions);

  if (loading || profileLoading) return <AuthLoading />;
  if (user) return <Navigate to={defaultRoute} replace />;

  return children;
}
