# HANDOFF

## Đã xong – v2.4.0 (đã commit + push main)
- Trang Task: "Tạo task" mặc định ngày Air = hôm nay (trước luôn mùng 1) – `src/pages/ContentPlan.tsx`.
- giao 007: nút copy kế nút mở link – `src/components/common/CopyLinkButton.tsx`, dùng ở ContentPlanModal, TaskTable, ContentPlanTable, TaskCardList, ContentPlanCardList.
- giao 008 + Claude: Workload desktop rê vào chỗ trống của ô → `.wl-list` mờ, lớp phủ giữa ô có "+ Task" (nút `btn` xanh) / "+ Quay" (`btn-ghost`), mở modal đúng ngày. Rê lên chip thì ẩn nút. `hover:none` → nút nhỏ ở đáy ô. Giữ 2 nút toolbar.
- giao 009: kéo thả HTML5 chip Task (content_plan chưa "Đã xong") và lịch quay để đổi ngày; lưu qua `useContentPlan().updateItem` / `useShoots().updateShoot`.
- Đã kiểm trên app thật (admin): hover/thêm đúng ngày, kéo Task 17→24 rồi về 17, copy link, ô tháng trước không nhận thả, console sạch.
- `/batdau`: `AGENTS.md` có thêm vùng nhạy cảm + lưu ý; `docs/TASKS.md`.

## Chưa kiểm
- Thả lịch quay thật (gọi `update_shoot_with_notifications` → thông báo/push thật cho crew).
- Copy link trên thẻ mobile; giao diện tối của lớp phủ Workload; Firefox (button draggable).
- Web Push gửi thật trên iPhone (từ v2.3.0). `VAPID_SUBJECT` còn tạm là URL Supabase.

## Việc tiếp theo: "Nhập từ content plan" (người dùng đã đồng ý hướng, CHƯA làm)
Bối cảnh: team content gửi link Excel OneDrive (cột D = Video/Motion, E = số ngày, F = nội dung nhiều dòng; ô gộp khi 1 ngày nhiều việc). Admin đang gõ tay từng Task BRAND, tên tự rút gọn, và khi plan đổi ngày Air phải dò sửa tay.
Hướng chốt: dán (Ctrl+C vùng D:F) vào modal ở trang Task – KHÔNG cần IT/OneDrive API, không thêm dependency.
- Tách: D Video→"Video dài", Motion→"Motion"; E → air_date trong tháng đang chọn; F dòng đầu → tên gợi ý (bỏ đoạn sau " - " cuối), toàn bộ F → Ghi chú; order BRAND; ô gộp trống thì lấy ngày/loại dòng trên; ô có xuống dòng (TSV có ngoặc kép).
- Bảng xem trước sửa tên/ngày tại chỗ. So với task trong THÁNG (không chỉ cùng ngày), khớp khi tên task đã có nằm trong chữ Excel:
  - Mới → tạo; Đã có (cùng ngày) → bỏ qua; Đổi ngày → tick sẵn cập nhật air_date (task đã xong không tick sẵn).
- Thông báo: hiện mỗi Task tạo mới gọi `create_content_plan_with_notifications` → báo Admin/Creative Manager từng cái. Cần RPC tạo nhiều + 1 thông báo gộp.
Plan:
1. Claude (xhigh, `--chi-claude`): RPC tạo nhiều Task + 1 thông báo gộp (`supabase/`).
2. giao (vừa): hàm tách dữ liệu dán + test nhỏ.
3. giao (khó, `--sau` 2): modal "Nhập từ content plan" ở `src/pages/ContentPlan.tsx` + preview + tạo/cập nhật.
4. Claude: duyệt diff + chạy app thật.
Để sau: đọc ảnh chụp plan bằng Claude API (Edge Function, cần API key + hỏi quy định công ty); đồng bộ thẳng OneDrive (cần IT/Azure).

## Quyết định đã chốt
- Giữ 2 nút toolbar "Thêm task / Thêm lịch quay". Kéo thả không cập nhật lạc quan, không hoàn tác; task "Đã xong" không kéo.
- Modal nền đặc; mỗi commit nâng version 3 chỗ (trừ commit chỉ đổi tài liệu); duyệt `giao` phải chạy app thật.

## Nợ / việc tồn
- Nút "+ Task/+ Quay" trong ô không Tab tới được (ẩn bằng `visibility`); bàn phím dùng nút toolbar.
- `.m-toolbar` margin -16px tràn `.calendar-page` 16px (mobile).
- Chưa có: badge số trên icon app, tắt push theo loại, nút push trên desktop.
