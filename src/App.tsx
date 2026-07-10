import { lazy, Suspense } from 'react';
import type { ReactNode } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import AppLayout from './components/layout/AppLayout';
import Login from './pages/Login';
import NotFound from './pages/NotFound';
import { ProtectedRoute, PublicOnlyRoute } from './components/auth/AuthRoutes';
import { DEFAULT_AUTHENTICATED_ROUTE } from './config/permissions';
import { ConfirmDialogProvider } from './components/common/ConfirmDialogProvider';
import { ToastProvider } from './components/common/ToastProvider';
import { LoadingState } from './components/common/LoadingState';
import { ErrorBoundary } from './components/common/ErrorBoundary';
import { MonthProvider } from './context/monthProvider';

const Dashboard = lazy(() => import('./pages/Dashboard'));
const Tasks = lazy(() => import('./pages/Tasks'));
const Calendar = lazy(() => import('./pages/Calendar'));
const Profile = lazy(() => import('./pages/Profile'));
const ContentPlan = lazy(() => import('./pages/ContentPlan'));
const Users = lazy(() => import('./pages/Users'));

function DefaultRedirect() {
  return <Navigate to={DEFAULT_AUTHENTICATED_ROUTE} replace />;
}

function RouteLoadingFallback() {
  return (
    <div className="route-loading" aria-busy="true">
      <LoadingState
        variant="block"
        message="Đang tải trang..."
        className="card route-loading-card"
      />
    </div>
  );
}

function lazyPage(element: ReactNode) {
  return <Suspense fallback={<RouteLoadingFallback />}>{element}</Suspense>;
}

function App() {
  return (
    <ToastProvider>
      <ConfirmDialogProvider>
        <ErrorBoundary>
          <MonthProvider>
            <BrowserRouter>
              <Routes>
                <Route path="/login" element={<PublicOnlyRoute><Login /></PublicOnlyRoute>} />
                
                <Route element={<ProtectedRoute><AppLayout /></ProtectedRoute>}>
                  <Route path="/" element={<DefaultRedirect />} />
                  <Route path="/dashboard" element={lazyPage(<Dashboard />)} />
                  <Route path="/tasks" element={lazyPage(<Tasks />)} />
                  <Route path="/content-plan" element={lazyPage(<ContentPlan />)} />
                  <Route path="/users" element={lazyPage(<Users />)} />
                  <Route path="/calendar" element={lazyPage(<Calendar />)} />
                  <Route path="/profile" element={lazyPage(<Profile />)} />
                  <Route path="*" element={<NotFound />} />
                </Route>
              </Routes>
            </BrowserRouter>
          </MonthProvider>
        </ErrorBoundary>
      </ConfirmDialogProvider>
    </ToastProvider>
  );
}

export default App;
