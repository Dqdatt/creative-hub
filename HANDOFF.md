# HANDOFF

Trạng thái: không có việc dở. Bản mới nhất v2.2.0 đã push lên `origin/main` (afb39b7).

## v2.2.0 – PWA Liquid Glass (xong 2026-11-20)
- Token kính + easing lò xo trong `src/components/mobile/mobile.css`, có fallback giảm trong suốt/chuyển động.
- Dock và nút chọn chế độ lịch có viên kính trượt (`--m-tab-index`, `--m-seg-index`).
- `BottomSheet.tsx`: kéo xuống để đóng, render qua `createPortal(document.body)`.
- PWA: màu splash/theme-color `#EDF1F7`, service worker v3, tự reload 1 lần khi lỗi tải chunk sau deploy (`src/pwa/pwa.ts`).
- Animation `.m-page` và `m-rise` dùng fill `backwards` để không giữ transform (transform giữ lại làm sheet/fixed bị kẹt dưới dock).

## Còn để ý
- Chưa thử trên iPhone thật: kéo sheet, kính mờ Safari.
- Lỗi cũ chưa sửa: `.m-toolbar` margin -16px tràn `.calendar-page` (overflow hidden) 16px, scrollIntoView có thể kéo lệch nội dung.
- Redesign PWA v3 (UI mobile riêng) đã tạm dừng theo quyết định người dùng.
