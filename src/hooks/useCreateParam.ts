import { useEffect, useRef } from 'react';
import { useLocation, useSearchParams } from 'react-router-dom';
import type { CreateKind } from '../components/mobile/mobileChrome';

// Nút + trên thanh điều hướng mobile mở form tạo mới bằng ?create=<loại>.
// Trang nào hỗ trợ loại đó thì mở đúng modal sẵn có rồi xóa tham số khỏi URL.
export function useCreateParam(handlers: Partial<Record<CreateKind, () => void>>, ready = true) {
  const [searchParams, setSearchParams] = useSearchParams();
  const { key } = useLocation();
  const handledKeyRef = useRef<string | null>(null);
  const kind = searchParams.get('create') as CreateKind | null;

  useEffect(() => {
    if (!kind || !ready || handledKeyRef.current === key) return;
    handledKeyRef.current = key;
    setSearchParams((current) => {
      const next = new URLSearchParams(current);
      next.delete('create');
      return next;
    }, { replace: true });
    handlers[kind]?.();
  }, [handlers, key, kind, ready, setSearchParams]);
}
