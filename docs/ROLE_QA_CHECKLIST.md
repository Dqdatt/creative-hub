# Role QA Checklist

Checklist kiểm thử quyền cho workflow CreativeHub hiện tại.

## Chuẩn bị

- Đăng nhập lần lượt bằng tài khoản `admin`, `creative_manager`, `content_creator`, `editor`.
- Với tài khoản admin có làm editor, kiểm tra `is_editor_member = true` và `editor_code` đã có giá trị như `dat`.
- Sau mỗi lần đổi vai trò hoặc trạng thái user, đăng xuất và đăng nhập lại để refresh profile role.

## Admin

- Sidebar hiển thị: Tổng quan, Lịch quay, Video tháng, Content Plan, Thành viên.
- Truy cập trực tiếp được `/dashboard`, `/calendar`, `/tasks`, `/content-plan`, `/users`, `/profile`.
- `/dashboard`: xem được KPI, workload editor, lịch quay và video task.
- `/calendar`: tạo, sửa, xóa lịch quay; gán một hoặc nhiều editor; Dashboard đếm `Buổi quay` theo assignment.
- `/tasks`: tạo và sửa Video tháng.
- `/content-plan`: tạo, sửa, xóa; sửa được Ngày Air, Tên video, Thể loại, Editor.
- `/users`: tạo thành viên, đổi vai trò, bật/tắt hoạt động, bật/tắt "Tham gia team editor".

## Creative Manager

- Sidebar hiển thị: Tổng quan, Lịch quay, Video tháng, Content Plan.
- Sidebar không hiển thị Thành viên.
- Truy cập trực tiếp `/users` phải redirect về `/dashboard`.
- `/dashboard`: xem được dữ liệu production.
- `/calendar`: tạo, sửa, xóa lịch quay; gán editor; editor assignment được lưu vào Dashboard.
- `/tasks`: tạo và sửa Video tháng.
- `/content-plan`: mở dòng bằng click row; chỉ field Editor có thể sửa, Ngày Air/Tên video/Thể loại bị disabled/dim.
- Lưu Content Plan không được thay đổi Ngày Air/Tên video/Thể loại.

## Content Creator

- Sau login mặc định vào `/content-plan`.
- Sidebar hiển thị: Lịch quay, Content Plan.
- Sidebar không hiển thị Tổng quan, Video tháng, Thành viên.
- Truy cập trực tiếp `/dashboard`, `/tasks`, `/users` phải redirect về `/content-plan`.
- `/calendar`: tạo, sửa, xóa lịch quay; gán editor; Dashboard admin đếm `Buổi quay` sau khi refresh hoặc realtime.
- `/content-plan`: tạo, sửa, xóa; sửa được Ngày Air, Tên video, Thể loại.
- Field Editor trong Content Plan bị disabled/dim và không đổi sau khi lưu.

## Editor

- Sidebar hiển thị: Tổng quan, Lịch quay, Video tháng, Content Plan.
- Sidebar không hiển thị Thành viên.
- Truy cập trực tiếp `/users` phải redirect về `/dashboard`.
- `/dashboard`: xem được dữ liệu production.
- `/tasks`: tạo và sửa Video tháng; không bị filter chỉ task của mình.
- `/calendar`: xem lịch quay; không có nút thêm; mở lịch chỉ xem chi tiết, không có nút lưu/xóa.
- `/content-plan`: chỉ xem table; row click không mở modal sửa; không có nút thêm/xóa/lưu.

## Kiểm tra lỗi không chặn workflow

- Nếu activity log lỗi, thao tác chính vẫn lưu thành công.
- Nếu gán editor lịch quay bị RLS chặn, modal phải hiện lỗi tiếng Việt, không lưu âm thầm assignment rỗng.
- Crew text tự do trong lịch quay không được tính vào Dashboard workload; chỉ `shoot_editors` mới được tính.
