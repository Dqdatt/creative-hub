# CreativeHub – Video Task Project

App nội bộ quản lý video/task cho team marketing. Web desktop + PWA mobile.

## Stack
- React 19 + TypeScript + Vite 8, React Router 7, Zustand, lucide-react.
- Tailwind v4 qua `@tailwindcss/vite` (không dùng CDN), CSS tự viết là chính.
- Supabase (`src/lib/supabase.ts`, migration trong `supabase/`). Không sửa `.env`.

## Lệnh
- `npm run dev` – dev server cổng 5173.
- `npm run build` – `tsc -b && vite build`, phải đạt trước khi báo xong.
- `npm run lint` – oxlint.

## Cấu trúc chính
- `src/pages/` các trang; `src/components/<khu>/` component theo khu (dashboard, tasks, calendar, workload, users, layout, common, mobile).
- Desktop: `src/components/layout/*`, style ở `src/index.css`.
- Mobile/PWA (màn < 768px, `<html data-mobile>`): `src/components/mobile/MobileShell.tsx` (topbar, dock tab, nút +), `BottomSheet.tsx`, style ở `src/components/mobile/mobile.css` (class `m-*`, token `--m-*`).
- PWA: `public/manifest.webmanifest`, `public/sw.js`, `src/pwa/pwa.ts`, màn chờ đầu tiên inline trong `index.html`.
- Theme sáng/tối: `src/context/ThemeContext.tsx` (class `dark` trên `<html>`, lưu `localStorage['vo-theme']`).
- Quyền và luật nghiệp vụ: `src/config/`, `src/services/`, `src/hooks/` – KHÔNG đổi khi việc chỉ là UI.

## Quy tắc
- Giữ mọi tính năng hiện có; không bỏ Overview, Calendar, bảng Video, bộ lọc, sidebar, modal task.
- Không đổi logic nghiệp vụ, KPI, phân quyền, dữ liệu Supabase nếu đặc tả không yêu cầu.
- Giữ nhãn tiếng Việt. Không thêm dependency mới nếu đặc tả không cho phép.
- Modal dùng nền đặc (quyết định v2.0.0), không làm kính mờ cho modal.
- Luôn tôn trọng `prefers-reduced-motion` và `prefers-reduced-transparency`.
- Sửa xong: chạy `npm run build`, không để lỗi TypeScript.
- Phiên bản hiển thị ở 3 chỗ: `package.json` "version", footer `src/components/layout/AppLayout.tsx`, `APP_VERSION` trong `src/pages/Account.tsx` – chỉ đổi khi được bảo.

## Hướng thiết kế
- Dashboard SaaS nội bộ cao cấp: sạch, nghiêm túc, hiện đại.
- Không màu trẻ con, không gradient ngẫu nhiên, không card demo quá to.
- Mobile/PWA: phong cách Liquid Glass kiểu iOS – kính chỉ cho khung (topbar, dock, sheet, control nổi), nội dung đọc trên nền đặc.
