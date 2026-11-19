# HANDOFF

## Mục tiêu phiên vừa rồi
Thử quy trình `giao` (Antigravity/Codex làm, Claude duyệt) bằng đợt redesign PWA Liquid Glass, chốt thành v2.2.0.

## Đã xong
- v2.2.0 đã push lên `origin/main` (afb39b7), HANDOFF dọn ở 27f8663. Không còn nhánh/worktree thừa.
- Token kính + easing lò xo, fallback giảm trong suốt/chuyển động (`src/components/mobile/mobile.css`).
- Dock và nút chọn chế độ lịch có viên kính trượt (`--m-tab-index`, `--m-seg-index`) trong `MobileShell.tsx`.
- `BottomSheet.tsx`: kéo xuống để đóng (vuốt nhanh phải đi đủ 16px), render qua `createPortal(document.body)`.
- PWA: màu splash/theme-color `#EDF1F7`, service worker v3, tự reload 1 lần khi lỗi tải chunk sau deploy (`src/pwa/pwa.ts`).
- `.m-page`, `m-rise` dùng fill `backwards`: transform bị giữ lại từng làm sheet kẹt dưới dock.
- AGENTS.md viết lại theo stack thật (React/Vite/TS), `CLAUDE.md` chỉ còn `@AGENTS.md`; dự án đã `giao init`.

## Đang dở
- Không có. Chưa thử v2.2 trên iPhone thật (kéo sheet, kính mờ Safari).

## Quyết định đã chốt
- Chỉ làm mobile/PWA (< 768px); desktop giữ nguyên. Modal dùng nền đặc, không kính.
- Không đổi status bar iOS sang `black-translucent` (chữ trắng trên nền sáng).
- Redesign PWA v3 (UI mobile riêng, prototype timeline tuần) đã DỪNG theo người dùng; prototype đã xoá khỏi repo.
- Duyệt việc `giao`: tự đọc diff + chạy app thật trước `giao xong`; nhãn review tự động chỉ để tham khảo.
- Mỗi commit nâng version ở 3 chỗ (package.json, footer AppLayout, `APP_VERSION` Account) – trừ commit chỉ đổi tài liệu.

## Nợ Ponytail
- Không có `shortcut:` mới.
- Lỗi cũ: `.m-toolbar` margin -16px tràn `.calendar-page` (overflow hidden) 16px, scrollIntoView có thể kéo lệch nội dung.

## Việc tiếp theo
1. [haiku] Sau khi Vercel deploy: mở PWA trên iPhone, thử kéo sheet Bộ lọc, chuyển tab, chế độ tối; báo lỗi nếu có.
2. [sonnet] Sửa tràn 16px của `.m-toolbar` trong `.calendar-page` (Workload/Lịch quay) – giao qua `giao` kèm `--kiem-tra "npm run build && npm run lint"`.

## File cần đọc đầu tiên
- `AGENTS.md`
- `src/components/mobile/MobileShell.tsx`
- `src/components/mobile/mobile.css`
- `src/components/mobile/BottomSheet.tsx`
- `src/pwa/pwa.ts`
