# Changelog

## 2.5.0 — 2026-08-28

- Thêm lệnh `ALCDIM`: chọn một DIM và đặt dimstyle của DIM đó thành dimstyle hiện hành.

## 2.4.1 — 2026-08-26

- Đặt màu nền hatch mặc định thành `TrueColor RGB 255,255,255` mỗi lần nạp `ALCWALL.lsp`.

## 2.4.0 — 2026-08-26

- Thêm `TKMS` để copy TEXT/MTEXT theo nhiều điểm và tự tăng hậu tố từ `-001` đến `-999`.
- Nếu text nguồn đã kết thúc bằng hậu tố ba chữ số, bản copy đầu tiên tiếp tục từ số kế tiếp.

## 2.3.0 — 2026-08-25

- Thêm lựa chọn `None` để hatch không có màu nền.
- Thêm lựa chọn nền trắng thực `TrueColor RGB 255,255,255`, tách biệt với ACI 7.
- Giữ nguyên chế độ nền của hatch khi dùng `ALCDOOR` để tách tường.

## 2.2.0 — 2026-08-22

- Sửa lỗi ghi `XRECORD` bằng `entmod` làm dữ liệu thiết lập tăng theo cấp số nhân sau mỗi lần lưu; nay thay mới dictionary entry bằng một record chuẩn.
- Thêm thiết lập màu nền hatch tường, mặc định ACI 9.
- Đổi màu hatch mặc định sang ACI 251 và hatch scale mặc định sang 250.
- Tự nâng cấp XRecord cũ để giá trị mặc định 5/500 không ghi đè mặc định mới.
- Giữ màu nền hatch khi dùng `ALCDOOR` để tách tường.
- Luôn đưa polyline boundary lên trên hatch để thấy rõ màu nét bao tường.

## 2.1.1 — 2026-08-18

- Sửa `TKALIGN` căn theo mép trái thực tế của bounding box thay vì điểm neo text.
- Text có justification trái, giữa hoặc phải vẫn về cùng một lề trái hiển thị.

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
