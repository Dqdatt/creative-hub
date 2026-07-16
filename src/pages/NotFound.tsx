import { Link } from 'react-router-dom';
import { Home, SearchX } from 'lucide-react';
import { getDefaultRouteForRole } from '../config/permissions';
import { useAuth } from '../context/authContext';

export default function NotFound() {
  const { role, permissions } = useAuth();
  const defaultRoute = getDefaultRouteForRole(role, permissions);

  return (
    <div className="not-found-page" data-view="not-found">
      <section className="card not-found-card">
        <span className="state-icon" aria-hidden="true">
          <SearchX />
        </span>
        <div>
          <h1>Không tìm thấy trang</h1>
          <p>Đường dẫn này không tồn tại hoặc bạn không có quyền truy cập.</p>
        </div>
        <Link className="btn" to={defaultRoute}>
          <Home /> Quay về trang chính
        </Link>
      </section>
    </div>
  );
}
