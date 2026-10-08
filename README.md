# ALCWALL 3.0.0

ALCWALL là bộ công cụ AutoLISP hỗ trợ triển khai tường ALC 2D trên AutoCAD for Windows. Bản 3.0.0 được kiểm thử bằng AutoCAD 2027.

## Cài đặt

1. Giữ nguyên toàn bộ cấu trúc thư mục, đặc biệt là `ALCWALL.lsp` và thư mục `src`.
2. Trong AutoCAD, mở `OPTIONS > Files > Support File Search Path` và thêm thư mục ALCWALL.
3. Chạy `APPLOAD`, chọn `ALCWALL.lsp`. Có thể thêm tệp này vào Startup Suite nếu muốn tự động nạp.
4. Khi thấy thông báo `ALCWALL v3.0.0 modules loaded`, bộ lệnh đã sẵn sàng.

Không nạp riêng các tệp trong `src`; `ALCWALL.lsp` là loader duy nhất.

## Các lệnh

| Lệnh | Công dụng |
|---|---|
| `ALCSET`, `ALCS`, `ALSC` | Đặt pattern, màu hatch, màu nền, tỷ lệ, góc hatch và chiều dày tường |
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
| `TKMS` | Copy TEXT/MTEXT và tự tăng hậu tố `-001` đến `-999` |
| `TKALIGN` | Căn lề trái nhiều TEXT/MTEXT theo text tham chiếu, giữ nguyên khoảng cách dọc |
| `ALCDIM` | Chọn một DIM và đặt dimstyle của DIM đó thành dimstyle hiện hành |

Thiết lập ALC chính được lưu trong bản vẽ bằng `XRECORD`. Chiều rộng và màu giằng tường được giữ trong phiên làm việc hiện tại.

Màu nền hatch có ba chế độ: màu ACI, `None` (không có nền) và
`TrueColor RGB 255,255,255` (nền trắng thực, không phải ACI 7 thích nghi).
Mỗi lần nạp `ALCWALL.lsp`, màu nền mặc định được đặt lại thành TrueColor trắng;
lựa chọn khác trong `ALCSET` có hiệu lực trong phiên hiện tại.

## Cấu trúc

- `ALCWALL.lsp`: loader và số phiên bản.
- `src/alc-settings.lsp`: cấu hình và giao diện thiết lập.
- `src/alc-styles.lsp`: khởi tạo text/dim style còn thiếu.
- `src/alc-geometry.lsp`: hình học, polyline, offset và chia polygon.
- `src/alc-wall.lsp`: tường, hatch, cửa, lanh tô và giằng.
- `src/alc-schedule.lsp`: các bảng thống kê và đánh số.
- `src/alc-align.lsp`: căn chỉnh TEXT/MTEXT.
- `src/alc-commands.lsp`: 16 lệnh công khai và quản lý Undo/lỗi.
- `tests`: smoke test, bộ sinh DWG và script chạy AutoCAD 2027.
- `legacy`: bản v1 nguyên khối để đối chiếu lịch sử.

## Kiểm thử

Chạy từ PowerShell:

```powershell
.\tests\run-autocad-tests.ps1 -FullAutoCAD
```

Script mở một tiến trình AutoCAD 2027 riêng và ghi nhãn phiên, PID, thời gian khởi động trong `tests/results/<session>/session.json`. Các lệnh dùng ActiveX nên cần AutoCAD đầy đủ; Core Console chỉ phù hợp kiểm tra nạp mã và XRecord. Các log ZWCAD trong bản ZIP gốc là dữ liệu lịch sử.

`ALCDOOR` chỉ thay tường cũ sau khi tạo thành công đủ hai boundary và hai hatch mới. Khi một bước thất bại, các đối tượng tạm bị xóa và tường cũ được giữ lại.

## Giới hạn hình học

- Chỉ hỗ trợ tường 2D tạo bởi các đoạn thẳng; không xử lý segment cung trong polyline.
- Các điểm được chiếu về mặt phẳng UCS hiện tại; nên tránh tường không đồng phẳng.
- Offset có thể thất bại tại góc quá gắt, đoạn quá ngắn hoặc hình tự giao.
- `ALCDOOR` cần đủ phần tường ở cả hai phía lỗ mở; cửa nằm đúng đầu mút sẽ bị từ chối để tránh tạo polygon suy biến.
- Layer chứa tường phải được mở khóa. Hatch pattern được chọn phải tồn tại trong AutoCAD.

## Tính năng 2.6.0

- Gõ `ALCS` hoặc `ALSC`, chọn `Angle` (A), nhập số độ thập phân. Góc mặc định 0°, lưu theo bản vẽ, góc âm hoặc trên 360° được chuẩn hóa. Đây là góc xoay thêm của hatch, không phải góc của mép tường. Hatch khi cắt cửa giữ góc ban đầu; lanh tô và giằng giữ thiết lập riêng.
- Gõ `ALSC`, chọn `Pattern` (P): bảng danh sách mẫu từ `acad.pat`/`acadiso.pat` có hình xem trước. Chọn mẫu rồi OK; Cancel giữ giá trị cũ. Preview minh họa mẫu ở góc hiện tại, không phản ánh tỷ lệ in. Giữ file `src/alc-patterns.dcl` cùng các module. PAT tùy chỉnh ngoài hai thư viện này chưa nằm trong bảng chọn.
- Mỗi lần load kiểm tra và chỉ tạo layer còn thiếu `0. Tuong ALC`: Blue (ACI 4), Continuous, lineweight 0.09 mm. Sau load, layer này được đặt làm current. Layer có sẵn được giữ nguyên toàn bộ thuộc tính, kể cả màu/nét/lineweight. Có thể bắt đầu vẽ trên layer này ngay sau load.

XRecord schema 3 bổ sung DXF 44 cho góc, giữ thiết lập của bản vẽ schema 2. Xem `REVIEW.txt` để biết các điểm cần cải tiến tiếp và giới hạn kiểm thử giao diện.

## Khởi tạo style — 3.0.0

Khi nạp `ALCWALL.lsp`, kiểm tra riêng từng tên layer, text style và dim style. Chỉ tạo tài nguyên chưa tồn tại; tên đã có được giữ nguyên toàn bộ thông số. Sau khi kiểm tra/tạo, lập tức đặt `0. Tuong ALC`, `alc text` và `ALC Dim TL` làm current. Dim style được Restore để áp dụng thông số đã lưu và xóa các override của dim style hiện hành trước đó.

Text style `alc text`: font `NGHIA5.SHX`, width factor 0.65, height 0 để dùng chiều cao của đối tượng/dim. Font cần có trong thư mục Fonts hoặc Support Path; bộ Lisp không kèm file font.

Dim style `ALC Dim TL` kế thừa ISO-25 của bản vẽ rồi đặt:

| Thuộc tính | Giá trị |
|---|---|
| Overall scale | 100.0000 |
| Text height | 3.0000 |
| Arrow size / Arrow | 1.8000 / ArchTick, cả hai đầu |
| Ext line offset / extension | 2.0000 / 1.0000 |
| Roundoff | 5.0000 |
| Fixed ext line length / enabled | 4.0000 / On |
| Large radius jog angle | 45° |
| Text offset / inside | 1.0000 / On |
| Dim line / Ext line color | 8 / 8 |
| Text color | 3 (Green) |
| Precision / Tol precision | 0 / 0 |
| Fit: text movement | 2 |
| Text style | alc text |

Các thông số khác giữ theo ISO-25. Nếu bản vẽ thiếu ISO-25, dùng nền ISO-25 từ template `acadiso.dwt` chuẩn AutoCAD 2027. Nếu `alc text` đã có thì dim style mới tham chiếu style có sẵn, không đổi font/width factor của nó.

Kiểm thử tài nguyên riêng trong Core Console: `tests/run-autocad-tests.ps1 -StylesOnly`. Kiểm thử đầy đủ hatch/cắt cửa: thêm `-FullAutoCAD`.

Bản 3.0.0 dùng tên `ALC Dim TL`. Khi tên mới chưa có, tạo với scale 100 và text height 3 rồi đặt current. Dim style cũ `ALC Dim TL65` được giữ lại để không đổi các DIM đã dùng nó.
