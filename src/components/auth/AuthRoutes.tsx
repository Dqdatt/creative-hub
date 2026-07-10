import type { ReactNode } from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { canAccessRoute, DEFAULT_AUTHENTICATED_ROUTE } from '../../config/permissions';
import { useAuth } from '../../context/authContext';
import { AuthLoading } from './AuthLoading';

interface RouteGateProps {
  children: ReactNode;
}

export function ProtectedRoute({ children }: RouteGateProps) {
  const { user, loading, profileLoading, role, permissions } = useAuth();
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

  if (!canAccessRoute(role, location.pathname, permissions)) {
    return <Navigate to={DEFAULT_AUTHENTICATED_ROUTE} replace />;
  }

  return children;
}

export function PublicOnlyRoute({ children }: RouteGateProps) {
  const { user, loading, profileLoading } = useAuth();

  if (loading || profileLoading) return <AuthLoading />;
  if (user) return <Navigate to={DEFAULT_AUTHENTICATED_ROUTE} replace />;

  return children;
}
