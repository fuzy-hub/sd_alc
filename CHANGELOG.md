# Changelog

## 2.1.0 — 2026-08-18

- Thêm lệnh `TKALIGN` để căn nhiều `TEXT/MTEXT` theo trục X của text tham chiếu.
- Giữ nguyên tọa độ Y và khoảng cách dọc giữa các text.
- Hỗ trợ text có justification khác nhau thông qua điểm neo của đối tượng.

## 2.0.1 — 2026-08-18

- Sửa chọn phía của `ALCGT` khi đường tham chiếu theo trục Y.
- Không còn tự chọn một phía khi điểm chỉ bên bị OSNAP/ORTHO kéo đúng lên đường tham chiếu.
- Thêm regression test cho bốn hướng dọc và trường hợp điểm chọn mơ hồ.
- Tự dọn tiến trình ZWCAD ẩn do test runner tạo.

## 2.0.0 — 2026-08-18

- Tách mã thành năm module: settings, geometry, wall, schedule và commands.
- Giữ `ALCWALL.lsp` làm loader tương thích cho 11 lệnh công khai.
- Bảo đảm transaction cho `ALCDOOR`: chỉ thay tường cũ khi đủ hai boundary và hai hatch mới.
- Dịch giằng `ALCGT` cách đường tham chiếu 50 mm như `ALCLT`.
- Thêm smoke test đủ 11 lệnh và năm DWG kiểm thử bằng ZWCAD 2027.
- Thêm hướng dẫn cài đặt, sử dụng, kiểm thử và giới hạn hình học.
