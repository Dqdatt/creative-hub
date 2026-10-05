import { useEffect, useSyncExternalStore } from 'react';

// Giao diện mobile (Liquid Glass) dùng cho màn hình hẹp hơn 768px, cả trên trình
// duyệt điện thoại lẫn khi đã cài PWA. Desktop giữ nguyên giao diện cũ.
const QUERY = '(max-width: 767px)';

function subscribe(listener: () => void) {
  const media = window.matchMedia(QUERY);
  media.addEventListener('change', listener);
  return () => media.removeEventListener('change', listener);
}

function getSnapshot() {
  return window.matchMedia(QUERY).matches;
}

export function useIsMobile() {
  return useSyncExternalStore(subscribe, getSnapshot, () => false);
}

/** Gắn data-mobile lên <html> để CSS toàn cục (modal, toast...) đổi sang kiểu mobile. */
export function useMobileDocumentFlag(isMobile: boolean) {
  useEffect(() => {
    const root = document.documentElement;
    root.toggleAttribute('data-mobile', isMobile);
    return () => root.removeAttribute('data-mobile');
  }, [isMobile]);
}
