# ALCWALL 2.1.0

ALCWALL là bộ công cụ AutoLISP hỗ trợ triển khai tường ALC 2D trên ZWCAD/AutoCAD for Windows. Nhánh `2.x` được kiểm thử bằng ZWCAD 2027 (`27.2.0.21636`).

## Cài đặt

1. Giữ nguyên toàn bộ cấu trúc thư mục, đặc biệt là `ALCWALL.lsp` và thư mục `src`.
2. Trong ZWCAD, mở `OPTIONS > Files > Support File Search Path` và thêm thư mục ALCWALL.
3. Chạy `APPLOAD`, chọn `ALCWALL.lsp`. Có thể thêm tệp này vào Startup Suite nếu muốn tự động nạp.
4. Khi thấy thông báo `ALCWALL v2.1.0 modules loaded`, bộ lệnh đã sẵn sàng.

Không nạp riêng các tệp trong `src`; `ALCWALL.lsp` là loader duy nhất.

## Các lệnh

| Lệnh | Công dụng |
|---|---|
| `ALCSET` | Đặt hatch, màu, tỷ lệ, chiều dày tường và chiều rộng cửa |
| `ALCWALL` | Vẽ tường từ một mép tham chiếu |
| `ALCCENTRAL` | Vẽ tường đối xứng qua tim |
| `ALCDOOR` | Cắt lỗ cửa trên tường ALC đã đóng |
| `ALCLT` | Vẽ lanh tô, cách đường tham chiếu 50 mm |
| `ALCGT` | Vẽ giằng tường, cách đường tham chiếu 50 mm |
| `ALCGTS` | Đặt chiều rộng và màu cho `ALCGT` |
| `ALCTK` | Lập bảng tổng chiều dài theo layer |
| `ALCTKC` | Thống kê block cửa |
| `TKDIM` | Cộng kích thước và tạo bảng |
| `TKCOUNT` | Đánh số tuần tự có khung |
| `TKALIGN` | Căn nhiều TEXT/MTEXT thẳng đứng theo text tham chiếu, giữ nguyên khoảng cách dọc |

Thiết lập ALC chính được lưu trong bản vẽ bằng `XRECORD`. Chiều rộng và màu giằng tường được giữ trong phiên làm việc hiện tại.

## Cấu trúc

- `ALCWALL.lsp`: loader và số phiên bản.
- `src/alc-settings.lsp`: cấu hình và giao diện thiết lập.
- `src/alc-geometry.lsp`: hình học, polyline, offset và chia polygon.
- `src/alc-wall.lsp`: tường, hatch, cửa, lanh tô và giằng.
- `src/alc-schedule.lsp`: các bảng thống kê và đánh số.
- `src/alc-align.lsp`: căn chỉnh TEXT/MTEXT.
- `src/alc-commands.lsp`: 12 lệnh công khai và quản lý Undo/lỗi.
- `tests`: smoke test, bộ sinh DWG và script chạy ZWCAD.
- `legacy`: bản v1 nguyên khối để đối chiếu lịch sử.

## Kiểm thử

Chạy từ PowerShell:

```powershell
.\tests\run-zwcad-tests.ps1
```

Script dùng `C:\Program Files\ZWSOFT\ZWCAD 2027\ZWCAD.exe` theo mặc định, kiểm tra đủ 12 lệnh và tạo năm bản vẽ trong `tests/fixtures`: tường thẳng, tường chữ L, tường chữ U, tường trong UCS xoay 30°, và các tình huống cửa sát biên/rollback khi hatch lỗi.

`ALCDOOR` chỉ thay tường cũ sau khi tạo thành công đủ hai boundary và hai hatch mới. Khi một bước thất bại, các đối tượng tạm bị xóa và tường cũ được giữ lại.

## Giới hạn hình học

- Chỉ hỗ trợ tường 2D tạo bởi các đoạn thẳng; không xử lý segment cung trong polyline.
- Các điểm được chiếu về mặt phẳng UCS hiện tại; nên tránh tường không đồng phẳng.
- Offset có thể thất bại tại góc quá gắt, đoạn quá ngắn hoặc hình tự giao.
- `ALCDOOR` cần đủ phần tường ở cả hai phía lỗ mở; cửa nằm đúng đầu mút sẽ bị từ chối để tránh tạo polygon suy biến.
- Layer chứa tường phải được mở khóa. Hatch pattern được chọn phải tồn tại trong ZWCAD.
