# HANDOFF – Redesign PWA Liquid Glass

Nhánh: `pwa-liquid-glass` (tách từ `main` @ 42c34ca). Đã commit c7012ed: AGENTS.md mới + CLAUDE.md (`@AGENTS.md`).

## Việc trong `giao` (dự án video-task-project)
- 001 Sửa cấu hình PWA: màu splash `#EDF1F7`, bỏ first-paint theo prefers-color-scheme, SW v3, `vite:preloadError` → reload 1 lần.
- 002 Token Liquid Glass + easing trong `src/components/mobile/mobile.css`.
- 003 (sau 002) Dock + segment có viên kính trượt (CSS var `--m-tab-index`), kéo sheet xuống để đóng.
- 004 (sau 003) Chuyển trang, list so le, phản hồi chạm, skeleton shimmer.
Kiểm tra mỗi việc: symlink node_modules vào worktree rồi `npm run build && npm run lint`.

## Quyết định
- Chỉ làm mobile/PWA (< 768px). Modal giữ nền đặc (v2.0.0). Không đổi status bar iOS (`black-translucent` làm chữ trắng trên nền sáng).
- Chưa có mẫu "Kavor" từ người dùng – đặc tả theo phong cách Liquid Glass iOS.

## Trạng thái (2026-11-20)
- 001–004: Claude đã duyệt diff, `giao xong` – đã merge vào `pwa-liquid-glass`. Build/lint đạt.
- Claude tự sửa thêm (CHƯA commit):
  - `BottomSheet.tsx`: vuốt nhanh phải đi đủ 16px mới đóng; render qua `createPortal(document.body)` vì trong trang bị dock đè (transform `.m-page` + sticky toolbar z-index 6).
  - `mobile.css`: `.m-sheet-backdrop` thêm font-size/color (ra ngoài `.m-shell`); `.m-page` và `m-rise` đổi fill `both` → `backwards` để không giữ transform sau animation.
- Đã soát preview 375px sáng/tối: dock trượt, segment, sheet kéo đóng/nảy về, theme-color. Console sạch.
- Lỗi cũ chưa sửa (ngoài phạm vi): `.m-toolbar` margin -16px tràn `.calendar-page` (overflow hidden) 16px – scrollIntoView có thể kéo lệch nội dung.

## Tiếp theo
1. Thử trên iPhone thật (kéo sheet, kính mờ Safari).
2. Bump v2.2.0 (package.json, AppLayout footer, Account `APP_VERSION`), commit khi người dùng bảo.
